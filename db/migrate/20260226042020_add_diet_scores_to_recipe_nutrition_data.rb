# frozen_string_literal: true

class AddDietScoresToRecipeNutritionData < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_nutrition_data, :diet_scores, :json
  end
end
