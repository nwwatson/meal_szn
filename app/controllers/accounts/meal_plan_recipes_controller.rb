class Accounts::MealPlanRecipesController < ApplicationController
  before_action :set_meal_plan
  before_action :set_recipe

  def show
    @meal_plans = Current.account.meal_plans
      .where("end_date >= ?", Date.current)
      .includes(days: { meals: :recipe })
      .order(start_date: :asc)
    @back_path = meal_plan_path(@meal_plan)
    @back_label = @meal_plan.name || "Meal Plan"
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])
  end

  def set_recipe
    @recipe = Current.account.recipes
      .includes(:ingredients, :instructions, :nutrition_data, :tips, :tags)
      .find(params[:id])
  end
end
