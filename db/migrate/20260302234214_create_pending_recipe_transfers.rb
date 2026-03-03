class CreatePendingRecipeTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_recipe_transfers, id: :string do |t|
      t.string :identity_id, null: false
      t.string :source_recipe_id, null: false

      t.timestamps
    end

    add_index :pending_recipe_transfers, :identity_id
    add_index :pending_recipe_transfers, [ :identity_id, :source_recipe_id ], unique: true
  end
end
