class CreateMealPlanDays < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_days, id: :string do |t|
      t.references :meal_plan, null: false, foreign_key: true, type: :string
      t.date :date, null: false
      t.integer :day_number, null: false

      t.timestamps
    end

    add_index :meal_plan_days, [ :meal_plan_id, :day_number ], unique: true
    add_index :meal_plan_days, [ :meal_plan_id, :date ], unique: true
  end
end
