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
    @shopping_list = @current_meal_plan&.shopping_lists&.includes(:items)&.last
    @dietary_profiles_count = Current.account.dietary_profiles.where(active: true).count

    load_macro_targets
  end

  private

  def load_macro_targets
    profile = Current.user&.dietary_profile ||
              Current.account.dietary_profiles.where(active: true).first

    @macro_targets = profile&.macro_targets
    @daily_calories_target = profile&.daily_calories_target ||
                             @current_meal_plan&.daily_calories_target
  end
end
