class AddUnitSystemToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :unit_system, :integer, default: 0, null: false
  end
end
