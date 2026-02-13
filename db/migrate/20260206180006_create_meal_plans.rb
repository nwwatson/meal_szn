class CreateMealPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plans, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.string :name
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :daily_calories_target

      t.timestamps
    end

    add_index :meal_plans, [ :account_id, :start_date ]
  end
end
