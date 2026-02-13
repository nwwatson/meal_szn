class CreateAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :accesses, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.string :entity_type, null: false
      t.string :entity_id, null: false
      t.integer :involvement, default: 0, null: false  # 0=access_only, 1=watching
      t.datetime :accessed_at

      t.timestamps
    end

    add_index :accesses, [ :user_id, :entity_type, :entity_id ], unique: true
    add_index :accesses, [ :entity_type, :entity_id ]
  end
end
