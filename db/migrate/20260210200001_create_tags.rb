class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags, id: :string do |t|
      t.string :account_id, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :tags, %i[account_id name], unique: true
    add_foreign_key :tags, :accounts
  end
end
