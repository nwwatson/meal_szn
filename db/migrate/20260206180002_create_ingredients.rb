class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients, id: :string do |t|
      t.references :recipe, null: false, foreign_key: true, type: :string
      t.string :name, null: false
      t.string :quantity
      t.string :unit
      t.integer :display_order, default: 0

      t.timestamps
    end

    add_index :ingredients, [ :recipe_id, :display_order ]
  end
end
