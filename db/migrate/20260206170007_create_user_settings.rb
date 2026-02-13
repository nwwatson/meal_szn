class CreateUserSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_settings, id: :string do |t|
      t.references :user, null: false, foreign_key: true, type: :string
      t.string :timezone
      t.integer :email_frequency, default: 0, null: false  # 0=never, 1=every_4_hours, 2=daily, 3=weekly

      t.timestamps
    end
  end
end
