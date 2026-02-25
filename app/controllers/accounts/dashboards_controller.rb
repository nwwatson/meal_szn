class Accounts::DashboardsController < ApplicationController
  def show
    @recent_recipes = Current.account.recipes
      .includes(:nutrition_data)
      .order(created_at: :desc)
      .limit(4)

    @current_meal_plan = Current.account.meal_plans
      .current
      .includes(days: { meals: { recipe: :nutrition_data } })
      .order(start_date: :desc)
      .first

    @today = @current_meal_plan&.days&.find { |d| d.date == Date.current }
    @shopping_list = @current_meal_plan&.shopping_lists&.last
    @dietary_profiles_count = Current.account.dietary_profiles.count
  end
end
