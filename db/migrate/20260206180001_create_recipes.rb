class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.string :title, null: false
      t.text :description
      t.integer :category, null: false, default: 0
      t.string :source
      t.integer :servings
      t.integer :prep_time  # in minutes
      t.integer :cook_time  # in minutes

      t.timestamps
    end

    add_index :recipes, [ :account_id, :category ]
    add_index :recipes, [ :account_id, :title ]
  end
end
