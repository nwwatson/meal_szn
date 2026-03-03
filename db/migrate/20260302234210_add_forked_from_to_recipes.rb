class AddForkedFromToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :forked_from_id, :string
    add_index :recipes, :forked_from_id
  end
end
