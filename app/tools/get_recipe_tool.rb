# frozen_string_literal: true

class GetRecipeTool < ApplicationTool
  tool_name "get_recipe"
  description "Get full details for a specific recipe including ingredients, instructions, nutrition data, and tips."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:recipe_id).filled(:string).description("The UUID of the recipe to retrieve")
  end

  def call(recipe_id:)
    recipe = current_account.recipes
      .includes(:ingredients, :instructions, :nutrition_data, :tips, :tags)
      .find_by(id: recipe_id)

    return error_response("Recipe not found") unless recipe

    {
      content: [
        { type: "text", text: JSON.generate({ recipe: recipe.to_api_response }) }
      ]
    }
  end

  private

  def error_response(message)
    { content: [ { type: "text", text: JSON.generate({ error: message }) } ], isError: true }
  end
end
