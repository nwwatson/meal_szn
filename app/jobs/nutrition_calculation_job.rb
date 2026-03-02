# frozen_string_literal: true

class NutritionCalculationJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(recipe_id)
    recipe = Recipe.includes(:ingredients, :nutrition_data).find(recipe_id)

    return if recipe.ingredients.none?

    result = Nutrition::Calculator.new(recipe).calculate
    return unless result.success?

    nutrition = recipe.nutrition_data || recipe.build_nutrition_data
    nutrition.update!(result.nutrition_data)
  end
end
