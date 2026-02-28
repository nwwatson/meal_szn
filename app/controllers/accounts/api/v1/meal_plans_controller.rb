class Accounts::Api::V1::MealPlansController < Accounts::Api::V1::ApplicationController
  include AiRateLimited

  before_action :require_write_permission!, only: %i[create update destroy generate swap_meal regenerate_day]
  before_action :set_meal_plan, only: %i[show update destroy swap_meal regenerate_day]
  before_action :set_user_for_create, only: %i[create generate]
  before_action :set_task, only: :generate_status
  before_action -> { check_ai_rate_limit!(:meal_plan_generation) }, only: :generate

  # GET /api/v1/meal_plans
  def index
    meal_plans = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .order(start_date: :desc)

    render json: {
      meal_plans: meal_plans.map { |plan|
        {
          id: plan.id,
          name: plan.name,
          start_date: plan.start_date,
          end_date: plan.end_date,
          duration_days: plan.duration_days,
          daily_calories_target: plan.daily_calories_target,
          average_daily_calories: plan.average_daily_calories.round
        }
      }
    }
  end

  # GET /api/v1/meal_plans/:id
  def show
    render json: { meal_plan: @meal_plan.to_api_response }
  end

  # POST /api/v1/meal_plans
  # Creates a meal plan, optionally with days and meals
  def create
    @meal_plan = current_account.meal_plans.build(meal_plan_params)
    @meal_plan.user = @user

    if @meal_plan.save
      render json: { meal_plan: @meal_plan.to_api_response }, status: :created
    else
      render json: { errors: @meal_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/meal_plans/:id
  def update
    if @meal_plan.update(meal_plan_params)
      render json: { meal_plan: @meal_plan.to_api_response }
    else
      render json: { errors: @meal_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/meal_plans/:id
  def destroy
    @meal_plan.destroy
    head :no_content
  end

  # POST /api/v1/meal_plans/generate
  def generate
    plan = current_account.meal_plans.build(meal_plan_params)
    plan.user = @user

    unless plan.save
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
      return
    end

    generate_days(plan)
    attach_participants(plan, params[:dietary_profile_ids])

    task = current_account.ai_task_statuses.create!(task_type: "meal_plan_generation")

    MealPlanGenerationJob.perform_later(
      task.id,
      meal_plan_id: plan.id,
      preferences: Array(params[:preferences]).reject(&:blank?),
      special_requests: params[:special_requests].presence
    )

    render json: {
      task_id: task.id,
      meal_plan_id: plan.id,
      status: task.status
    }, status: :created
  end

  # GET /api/v1/meal_plans/generate_status/:task_id
  def generate_status
    response = {
      task_id: @task.id,
      status: @task.status,
      progress_percentage: @task.progress_percentage
    }

    if @task.completed?
      raw = @task.result
      response[:result] = raw.is_a?(String) ? JSON.parse(raw) : raw
    end
    response[:error_message] = @task.error_message if @task.failed?

    render json: response
  end

  # POST /api/v1/meal_plans/:id/swap_meal
  def swap_meal
    meal_id = params[:meal_id]
    recipe_id = params[:recipe_id]

    if meal_id.blank? || recipe_id.blank?
      render json: { error: "meal_id and recipe_id are required" }, status: :bad_request
      return
    end

    meal = @meal_plan.days.joins(:meals).where(meal_plan_meals: { id: meal_id }).first&.meals&.find_by(id: meal_id)
    unless meal
      render json: { error: "Meal not found in this plan" }, status: :not_found
      return
    end

    recipe = current_account.recipes.find_by(id: recipe_id)
    unless recipe
      render json: { error: "Recipe not found" }, status: :not_found
      return
    end

    meal.update!(recipe: recipe)

    render json: { meal_plan: @meal_plan.reload.to_api_response }
  end

  # POST /api/v1/meal_plans/:id/regenerate_day
  def regenerate_day
    day_number = params[:day_number].to_i

    day = @meal_plan.days.find_by(day_number: day_number)
    unless day
      render json: { error: "Day #{day_number} not found in this plan" }, status: :not_found
      return
    end

    day.meals.destroy_all

    generator = MealPlanGenerator.new(
      @meal_plan.reload,
      preferences: Array(params[:preferences]).reject(&:blank?),
      special_requests: params[:special_requests].presence
    )
    generator.generate

    render json: { meal_plan: @meal_plan.reload.to_api_response }
  rescue MealPlanGenerator::GenerationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_meal_plan
    @meal_plan = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Meal plan not found" }, status: :not_found
  end

  def set_user_for_create
    @user = current_account.users.find_by(identity: current_identity)

    unless @user
      render json: { error: "User not found in this account" }, status: :forbidden
    end
  end

  def set_task
    @task = current_account.ai_task_statuses.find(params[:task_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Task not found" }, status: :not_found
  end

  def generate_days(plan)
    (plan.start_date..plan.end_date).each_with_index do |date, index|
      plan.days.create!(date: date, day_number: index + 1)
    end
  end

  def attach_participants(plan, profile_ids)
    return unless profile_ids.present?

    Array(profile_ids).reject(&:blank?).each do |profile_id|
      profile = current_account.dietary_profiles.active.find_by(id: profile_id)
      next unless profile

      plan.participants.create!(dietary_profile: profile)
    end
  end

  def meal_plan_params
    params.require(:meal_plan).permit(
      :name,
      :start_date,
      :end_date,
      :daily_calories_target,
      days_attributes: [
        :id,
        :date,
        :day_number,
        :_destroy,
        meals_attributes: %i[id recipe_id meal_type servings _destroy]
      ]
    )
  end
end
