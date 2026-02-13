class CreateMealPlanParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_participants, id: :string do |t|
      t.references :meal_plan, null: false, foreign_key: true, type: :string
      t.references :dietary_profile, null: false, foreign_key: true, type: :string

      t.timestamps
    end

    add_index :meal_plan_participants, [ :meal_plan_id, :dietary_profile_id ],
              unique: true, name: "idx_meal_plan_participants_unique"
  end
end
