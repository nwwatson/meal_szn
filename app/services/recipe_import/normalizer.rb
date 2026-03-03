# frozen_string_literal: true

module RecipeImport
  module Normalizer
    def normalize(input)
      instructions = (input["instructions"] || []).map.with_index(1) do |text, i|
        { step_number: i, instruction: text }
      end

      nutrition = {
        calories: input["calories"],
        fat: input["fat"],
        protein: input["protein"],
        carbs: input["carbs"],
        fiber: input["fiber"]
      }.compact.presence

      {
        title: input["title"],
        description: input["description"],
        servings: input["servings"],
        prep_time: input["prep_time"],
        cook_time: input["cook_time"],
        ingredients: input["ingredients"] || [],
        instructions: instructions,
        nutrition: nutrition
      }.compact
    end
  end
end
