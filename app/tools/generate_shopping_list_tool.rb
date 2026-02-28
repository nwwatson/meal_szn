# frozen_string_literal: true

class GenerateShoppingListTool < ApplicationTool
  tool_name "generate_shopping_list"
  description "Generate a consolidated shopping list from a meal plan. Aggregates ingredients across all meals and days."

  arguments do
    required(:meal_plan_id).filled(:string).description("The UUID of the meal plan to generate a shopping list for")
  end

  def call(meal_plan_id:)
    plan = current_account.meal_plans
      .includes(days: { meals: { recipe: :ingredients } })
      .find_by(id: meal_plan_id)

    return error_response("Meal plan not found") unless plan

    shopping_list = ShoppingListGenerator.new(plan, user: Current.user).generate

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            meal_plan_id: plan.id,
            meal_plan_name: plan.name,
            shopping_list: {
              id: shopping_list.id,
              items: shopping_list.items.order(:name).map { |item|
                {
                  name: item.name,
                  quantity: item.quantity,
                  unit: item.unit,
                  checked: item.checked
                }
              }
            }
          })
        }
      ]
    }
  end

  private

  def error_response(message)
    { content: [ { type: "text", text: JSON.generate({ error: message }) } ], isError: true }
  end
end
