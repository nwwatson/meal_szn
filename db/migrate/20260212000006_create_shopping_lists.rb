class CreateShoppingLists < ActiveRecord::Migration[8.1]
  def change
    create_table :shopping_lists, id: :string do |t|
      t.string :account_id, null: false
      t.string :user_id, null: false
      t.string :meal_plan_id, null: false
      t.string :name

      t.timestamps
    end

    add_index :shopping_lists, :account_id
    add_index :shopping_lists, :meal_plan_id
    add_index :shopping_lists, :user_id
    add_foreign_key :shopping_lists, :accounts
    add_foreign_key :shopping_lists, :users
    add_foreign_key :shopping_lists, :meal_plans

    create_table :shopping_list_items, id: :string do |t|
      t.string :shopping_list_id, null: false
      t.string :name, null: false
      t.string :quantity
      t.string :unit
      t.boolean :checked, default: false, null: false

      t.timestamps
    end

    add_index :shopping_list_items, :shopping_list_id
    add_foreign_key :shopping_list_items, :shopping_lists
  end
end
