class Accounts::DashboardsController < ApplicationController
  def show
    @recent_recipes = Current.account.recipes.order(created_at: :desc).limit(5) if defined?(Recipe)
    @current_meal_plan = Current.account.meal_plans
      .current
      .includes(days: { meals: { recipe: :nutrition_data } })
      .order(start_date: :desc)
      .first
  end
end
