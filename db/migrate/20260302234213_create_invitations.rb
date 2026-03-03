class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :string do |t|
      t.string :account_id, null: false
      t.string :invited_by_id, null: false
      t.string :email_address, null: false
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, :account_id
    add_index :invitations, [ :account_id, :email_address ]
  end
end
