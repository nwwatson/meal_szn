class CreateNutritionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :nutrition_items, id: :string do |t|
      t.integer :fdc_id, null: false
      t.string :description, null: false
      t.integer :calories
      t.decimal :fat, precision: 8, scale: 2
      t.decimal :protein, precision: 8, scale: 2
      t.decimal :carbs, precision: 8, scale: 2
      t.decimal :fiber, precision: 8, scale: 2
      t.integer :sodium
      t.integer :potassium
      t.integer :magnesium
      t.boolean :portions_fetched, default: false

      t.timestamps
    end

    add_index :nutrition_items, :fdc_id, unique: true
  end
end
