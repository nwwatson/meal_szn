class AddRatingToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :rating, :integer
    add_index :recipes, [ :account_id, :rating ]
  end
end
