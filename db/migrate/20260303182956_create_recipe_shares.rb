class CreateRecipeShares < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_shares, id: :string do |t|
      t.string :recipe_id, null: false
      t.string :sender_id, null: false
      t.string :recipient_email, null: false
      t.string :recipient_user_id
      t.string :token, null: false
      t.integer :status, default: 0, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :recipe_shares, :token, unique: true
    add_index :recipe_shares, :recipient_email
    add_index :recipe_shares, :sender_id
    add_index :recipe_shares, :recipe_id
    add_foreign_key :recipe_shares, :recipes
    add_foreign_key :recipe_shares, :users, column: :sender_id
    add_foreign_key :recipe_shares, :users, column: :recipient_user_id

    add_column :recipes, :shared_by, :string
    add_column :recipes, :forked_from_id, :string
    add_index :recipes, :forked_from_id
  end
end
