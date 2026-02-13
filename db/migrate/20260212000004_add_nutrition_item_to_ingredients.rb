class AddNutritionItemToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_reference :ingredients, :nutrition_item, type: :string, foreign_key: true, null: true
  end
end
