class CreateNutritionItemPortions < ActiveRecord::Migration[8.1]
  def change
    create_table :nutrition_item_portions, id: :string do |t|
      t.references :nutrition_item, type: :string, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 8, scale: 2
      t.string :unit
      t.decimal :gram_weight, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :nutrition_item_portions, [ :nutrition_item_id, :unit ], name: "index_nutrition_item_portions_on_item_and_unit"
  end
end
