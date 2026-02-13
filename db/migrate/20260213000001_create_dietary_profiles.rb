class CreateDietaryProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :dietary_profiles, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.references :user, foreign_key: true, type: :string, index: false, null: true
      t.string :name, null: false
      t.string :diet_name
      t.integer :daily_calories_target
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :dietary_profiles, [ :account_id, :name ], unique: true
    add_index :dietary_profiles, :user_id
  end
end
