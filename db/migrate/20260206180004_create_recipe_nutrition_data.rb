class CreateRecipeNutritionData < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_nutrition_data, id: :string do |t|
      t.references :recipe, null: false, foreign_key: true, type: :string
      t.integer :calories
      t.decimal :fat, precision: 6, scale: 1        # grams
      t.decimal :protein, precision: 6, scale: 1    # grams
      t.decimal :carbs, precision: 6, scale: 1      # grams
      t.decimal :fiber, precision: 6, scale: 1      # grams
      t.decimal :net_carbs, precision: 6, scale: 1  # grams (carbs - fiber)
      t.integer :sodium                              # milligrams
      t.integer :potassium                           # milligrams
      t.integer :magnesium                           # milligrams

      t.timestamps
    end

    # add_index :recipe_nutrition_data, :recipe_id, unique: true
  end
end
