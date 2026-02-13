class AddDefaultDietToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :default_diet_name, :string
    add_column :accounts, :default_daily_calories_target, :integer
  end
end
