class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.references :identity, foreign_key: true, type: :string  # nullable for system users
      t.string :name, null: false
      t.integer :role, default: 2, null: false  # 0=owner, 1=admin, 2=member, 3=system
      t.boolean :active, default: true, null: false
      t.datetime :verified_at

      t.timestamps
    end

    add_index :users, [ :account_id, :identity_id ], unique: true, where: "identity_id IS NOT NULL"
  end
end
