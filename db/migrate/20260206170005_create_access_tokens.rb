class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens, id: :string do |t|
      t.references :identity, null: false, foreign_key: true, type: :string
      t.string :token, null: false
      t.string :description
      t.integer :permission, default: 0, null: false  # 0=read, 1=write
      t.datetime :expires_at  # null = never expires
      t.datetime :last_used_at
      t.string :last_used_ip
      t.datetime :revoked_at  # soft revocation

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
    add_index :access_tokens, :expires_at
    add_index :access_tokens, :revoked_at
  end
end
