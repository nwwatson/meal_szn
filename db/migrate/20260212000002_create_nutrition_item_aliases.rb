class CreateNutritionItemAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :nutrition_item_aliases, id: :string do |t|
      t.references :nutrition_item, type: :string, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :nutrition_item_aliases, :name, unique: true
  end
end
