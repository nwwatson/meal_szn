class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links, id: :string do |t|
      t.references :identity, null: false, foreign_key: true, type: :string
      t.string :code, null: false
      t.integer :purpose, default: 0, null: false  # 0=sign_in, 1=sign_up, 2=onboarding
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :magic_links, :code, unique: true
    add_index :magic_links, :expires_at
  end
end
