# frozen_string_literal: true

class GetMealPlanTool < ApplicationTool
  tool_name "get_meal_plan"
  description "Get full details of a meal plan including all days, meals, recipes, and daily nutrition totals."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:meal_plan_id).filled(:string).description("The UUID of the meal plan to retrieve")
  end

  def call(meal_plan_id:)
    plan = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .find_by(id: meal_plan_id)

    return error_response("Meal plan not found") unless plan

    {
      content: [
        { type: "text", text: JSON.generate({ meal_plan: plan.to_api_response }) }
      ]
    }
  end

  private

  def error_response(message)
    { content: [ { type: "text", text: JSON.generate({ error: message }) } ], isError: true }
  end
end
