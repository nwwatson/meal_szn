# frozen_string_literal: true

class ListMealPlansTool < ApplicationTool
  tool_name "list_meal_plans"
  description "List all meal plans for the account, ordered by start date (newest first)."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
  end

  def call
    plans = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .order(start_date: :desc)

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            meal_plans: plans.map { |plan|
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
          })
        }
      ]
    }
  end
end
