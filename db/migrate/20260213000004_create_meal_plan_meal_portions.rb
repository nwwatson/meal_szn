class CreateMealPlanMealPortions < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_meal_portions, id: :string do |t|
      t.references :meal_plan_meal, null: false, foreign_key: true, type: :string
      t.references :meal_plan_participant, null: false, foreign_key: true, type: :string
      t.decimal :servings, precision: 4, scale: 2, null: false, default: 1.0

      t.timestamps
    end

    add_index :meal_plan_meal_portions, [ :meal_plan_meal_id, :meal_plan_participant_id ],
              unique: true, name: "idx_meal_portions_unique"
  end
end
