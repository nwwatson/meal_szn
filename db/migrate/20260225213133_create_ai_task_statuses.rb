class CreateAiTaskStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_task_statuses, id: :string do |t|
      t.references :account, null: false, foreign_key: true, type: :string
      t.integer :status, null: false, default: 0
      t.string :task_type, null: false
      t.json :result
      t.string :error_message
      t.integer :progress_percentage, null: false, default: 0

      t.timestamps
    end

    add_index :ai_task_statuses, [ :account_id, :status ]
  end
end
