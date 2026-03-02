class Accounts::MealPlanMealsController < ApplicationController
  before_action :set_meal_plan

  def create
    day = @meal_plan.days.find(params[:meal_plan_day_id])
    @meal = day.meals.build(meal_params)

    respond_to do |format|
      if @meal.save
        auto_create_portions_for(@meal)
        format.html { redirect_back fallback_location: meal_plan_path(@meal_plan), notice: "Meal added." }
        format.json { render json: { status: "ok", meal_id: @meal.id }, status: :created }
      else
        format.html { redirect_back fallback_location: meal_plan_path(@meal_plan), alert: "Could not add meal." }
        format.json { render json: { status: "error", errors: @meal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def move
    meal = find_meal(params[:id])
    target_day = @meal_plan.days.find(params[:target_day_id])

    meal.meal_plan_day = target_day
    meal.meal_type = params[:target_meal_type] if params[:target_meal_type].present?

    respond_to do |format|
      if meal.save
        format.html { redirect_back fallback_location: meal_plan_path(@meal_plan), notice: "Meal moved." }
        format.json { render json: { status: "ok", meal_id: meal.id } }
      else
        format.html { redirect_back fallback_location: meal_plan_path(@meal_plan), alert: "Could not move meal." }
        format.json { render json: { status: "error", errors: meal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def swap
    @meal = find_meal(params[:id])
    @recipes = Current.account.recipes
      .includes(:nutrition_data)
      .where(category: @meal.recipe.category)
      .where.not(id: @meal.recipe_id)
      .order(:title)
      .limit(20)

    render partial: "accounts/meal_plans/swap_panel", locals: {
      meal: @meal, recipes: @recipes, meal_plan: @meal_plan
    }
  end

  def perform_swap
    @meal = find_meal(params[:id])
    recipe = Current.account.recipes.find(params[:recipe_id])

    @meal.update!(recipe: recipe)
    recalculate_portions_for(@meal)

    redirect_to meal_plan_path(@meal_plan), notice: "Meal swapped to #{recipe.title}."
  end

  def destroy
    meal = find_meal(params[:id])
    meal.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: meal_plan_path(@meal_plan), notice: "Meal removed." }
      format.json { render json: { status: "ok" } }
    end
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])
  end

  def find_meal(id)
    MealPlanMeal.joins(meal_plan_day: :meal_plan)
      .where(meal_plans: { account_id: Current.account.id, id: @meal_plan.id })
      .find(id)
  end

  def meal_params
    params.require(:meal).permit(:recipe_id, :meal_type, :servings)
  end

  def auto_create_portions_for(meal)
    @meal_plan.participants.includes(:dietary_profile).each do |participant|
      calculator = PortionCalculator.new(participant)
      day_portions = calculator.suggest_portions_for_day(meal.meal_plan_day)
      servings = day_portions[meal.id] || 1.0
      participant.portions.create!(meal_plan_meal: meal, servings: servings)
    end
  end

  def recalculate_portions_for(meal)
    @meal_plan.participants.includes(:dietary_profile).each do |participant|
      calculator = PortionCalculator.new(participant)
      day_portions = calculator.suggest_portions_for_day(meal.meal_plan_day)
      portion = participant.portions.find_by(meal_plan_meal: meal)
      if portion
        portion.update!(servings: day_portions[meal.id] || 1.0)
      else
        participant.portions.create!(meal_plan_meal: meal, servings: day_portions[meal.id] || 1.0)
      end
    end
  end
end
