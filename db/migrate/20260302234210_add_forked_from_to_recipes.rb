class AddForkedFromToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :forked_from_id, :string unless column_exists?(:recipes, :forked_from_id)
    add_index :recipes, :forked_from_id unless index_exists?(:recipes, :forked_from_id)
  end
end
