class CreateMealPlanMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_meals, id: :string do |t|
      t.references :meal_plan_day, null: false, foreign_key: true, type: :string
      t.references :recipe, null: false, foreign_key: true, type: :string
      t.integer :meal_type, null: false  # breakfast, lunch, dinner, snack
      t.decimal :servings, precision: 4, scale: 2, default: 1.0

      t.timestamps
    end

    add_index :meal_plan_meals, [ :meal_plan_day_id, :meal_type ]
  end
end
