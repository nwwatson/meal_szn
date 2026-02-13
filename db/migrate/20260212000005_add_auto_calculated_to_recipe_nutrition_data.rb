class AddAutoCalculatedToRecipeNutritionData < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_nutrition_data, :auto_calculated, :boolean, default: false, null: false
  end
end
