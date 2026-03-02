class Accounts::MealPlansController < ApplicationController
  include AiRateLimited

  before_action :set_meal_plan, only: %i[show edit update destroy duplicate regenerate_day]
  before_action -> { check_ai_rate_limit!(:meal_plan_generation, redirect_path: new_meal_plan_path) },
                only: %i[start_generate regenerate_day]

  def index
    plans = Current.account.meal_plans.includes(:days).recent
    @current_plans = plans.select(&:current?)
    @upcoming_plans = plans.select { |p| p.start_date > Date.current }
    @past_plans = plans.select { |p| p.end_date < Date.current }
  end

  def show
    @days = @meal_plan.days.includes(meals: { recipe: :nutrition_data }).order(:day_number)
    @participants = @meal_plan.participants.includes(:dietary_profile, portions: { meal_plan_meal: { recipe: :nutrition_data } })
    @available_profiles = Current.account.dietary_profiles.active.order(:name)
    @shopping_list = @meal_plan.shopping_lists.order(created_at: :desc).first
  end

  def new
    next_monday = Date.current.beginning_of_week + 7.days
    @meal_plan = Current.account.meal_plans.build(
      start_date: next_monday,
      end_date: next_monday + 6.days
    )
  end

  def create
    @meal_plan = Current.account.meal_plans.build(meal_plan_params)
    @meal_plan.user = Current.user

    if @meal_plan.save
      generate_days(@meal_plan)
      attach_participants(@meal_plan, params[:dietary_profile_ids])
      redirect_to meal_plan_path(@meal_plan), notice: "Meal plan was successfully created."
    else
      @available_profiles = Current.account.dietary_profiles.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_start = @meal_plan.start_date
    old_end = @meal_plan.end_date

    if @meal_plan.update(meal_plan_params)
      sync_days(@meal_plan, old_start, old_end) if @meal_plan.start_date != old_start || @meal_plan.end_date != old_end
      redirect_to meal_plan_path(@meal_plan), notice: "Meal plan was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @meal_plan.destroy
    redirect_to meal_plans_path, notice: "Meal plan was successfully deleted."
  end

  def start_generate
    @meal_plan = Current.account.meal_plans.build(meal_plan_params)
    @meal_plan.user = Current.user

    unless @meal_plan.save
      @available_profiles = Current.account.dietary_profiles.active.order(:name)
      return render :new, status: :unprocessable_entity
    end

    generate_days(@meal_plan)
    attach_participants(@meal_plan, params[:dietary_profile_ids])

    task = Current.account.ai_task_statuses.create!(task_type: "meal_plan_generation")

    MealPlanGenerationJob.perform_later(
      task.id,
      meal_plan_id: @meal_plan.id,
      preferences: Array(params[:ai_preferences]).reject(&:blank?),
      special_requests: params[:ai_special_requests].presence
    )

    redirect_to generate_status_meal_plans_path(task_id: task.id, meal_plan_id: @meal_plan.id)
  end

  def generate_status
    @task = Current.account.ai_task_statuses.find(params[:task_id])
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])

    if @task.completed?
      redirect_to meal_plan_path(@meal_plan), notice: "AI meal plan generated successfully!"
    elsif @task.failed?
      redirect_to meal_plan_path(@meal_plan), alert: "Generation failed: #{@task.error_message}"
    end
  end

  def regenerate_day
    day_number = params[:day_number].to_i
    day = @meal_plan.days.find_by(day_number: day_number)

    unless day
      redirect_to meal_plan_path(@meal_plan), alert: "Day #{day_number} not found."
      return
    end

    day.meals.destroy_all

    generator = MealPlanGenerator.new(@meal_plan.reload)
    generator.generate

    redirect_to meal_plan_path(@meal_plan), notice: "Day #{day_number} regenerated with new meals."
  rescue MealPlanGenerator::GenerationError, Ai::Client::AuthenticationError => e
    redirect_to meal_plan_path(@meal_plan), alert: "Regeneration failed: #{e.message}"
  end

  def duplicate
    new_start = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_week + 7.days
    new_end = params[:end_date].present? ? Date.parse(params[:end_date]) : new_start + (@meal_plan.duration_days - 1).days
    new_name = params[:name].presence || "Copy of #{@meal_plan.name}"

    new_plan = Current.account.meal_plans.create!(
      user: Current.user,
      name: new_name,
      start_date: new_start,
      end_date: new_end,
      daily_calories_target: @meal_plan.daily_calories_target
    )

    source_days = @meal_plan.days.includes(meals: :recipe).order(:day_number).to_a
    return redirect_to meal_plan_path(new_plan), notice: "Meal plan duplicated." if source_days.empty?

    new_duration = (new_end - new_start).to_i + 1
    new_duration.times do |i|
      date = new_start + i.days
      day = new_plan.days.create!(date: date, day_number: i + 1)

      source_day = source_days[i % source_days.size]
      source_day.meals.each do |meal|
        day.meals.create!(recipe: meal.recipe, meal_type: meal.meal_type, servings: meal.servings)
      end
    end

    # Copy participants and auto-calculate portions
    @meal_plan.participants.each do |orig_participant|
      new_participant = new_plan.participants.create!(dietary_profile: orig_participant.dietary_profile)
      calculator = PortionCalculator.new(new_participant)
      calculator.suggest_all.each_value do |day_portions|
        day_portions.each do |meal_id, servings|
          new_participant.portions.create!(meal_plan_meal_id: meal_id, servings: servings)
        end
      end
    end

    redirect_to meal_plan_path(new_plan), notice: "Meal plan duplicated."
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:id])
  end

  def meal_plan_params
    params.require(:meal_plan).permit(:name, :start_date, :end_date, :daily_calories_target)
  end

  def generate_days(plan)
    (plan.start_date..plan.end_date).each_with_index do |date, index|
      plan.days.create!(date: date, day_number: index + 1)
    end
  end

  def attach_participants(plan, profile_ids)
    return unless profile_ids.present?

    Array(profile_ids).reject(&:blank?).each do |profile_id|
      profile = Current.account.dietary_profiles.active.find_by(id: profile_id)
      next unless profile

      plan.participants.create!(dietary_profile: profile)
    end
  end

  def sync_days(plan, old_start, old_end)
    new_dates = (plan.start_date..plan.end_date).to_a

    # Remove days outside new range
    plan.days.where.not(date: new_dates).destroy_all

    # Add missing days and renumber
    new_dates.each_with_index do |date, index|
      day = plan.days.find_or_initialize_by(date: date)
      day.day_number = index + 1
      day.save!
    end
  end
end
