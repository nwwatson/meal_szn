class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :string do |t|
      t.bigint :external_account_id, null: false
      t.string :name, null: false
      t.boolean :cancelled, default: false, null: false

      t.timestamps
    end

    add_index :accounts, :external_account_id, unique: true
  end
end
