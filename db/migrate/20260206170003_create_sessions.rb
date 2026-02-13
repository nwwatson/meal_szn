class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :string do |t|
      t.references :identity, null: false, foreign_key: true, type: :string
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :sessions, :expires_at
  end
end
