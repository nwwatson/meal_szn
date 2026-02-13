class CreateAccountCancellations < ActiveRecord::Migration[8.1]
  def change
    create_table :account_cancellations, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string  # initiated_by

      t.timestamps
    end

    # add_index :account_cancellations, :account_id, unique: true
  end
end
