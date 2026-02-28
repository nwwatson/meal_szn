# frozen_string_literal: true

class GetNutritionInfoTool < ApplicationTool
  tool_name "get_nutrition_info"
  description "Get detailed nutrition information for a specific recipe, including per-serving macros and diet compatibility."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:recipe_id).filled(:string).description("The UUID of the recipe")
  end

  def call(recipe_id:)
    recipe = current_account.recipes
      .includes(:nutrition_data)
      .find_by(id: recipe_id)

    return error_response("Recipe not found") unless recipe
    return error_response("No nutrition data available for this recipe") unless recipe.nutrition_data

    nutrition = recipe.nutrition_data

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            recipe_id: recipe.id,
            title: recipe.title,
            servings: recipe.servings,
            nutrition_per_serving: nutrition.to_api_response,
            compatible_diets: nutrition.compatible_diets.map(&:to_s)
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
