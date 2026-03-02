class CreateAiRequestMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_request_metrics, id: :string do |t|
      t.references :account, type: :string, null: true, foreign_key: true
      t.string :feature, null: false
      t.string :model, null: false
      t.string :method_name, null: false
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.integer :cache_creation_input_tokens, default: 0
      t.integer :cache_read_input_tokens, default: 0
      t.float :duration_ms
      t.boolean :cache_hit, default: false
      t.string :error_class
      t.string :error_message

      t.timestamps
    end

    add_index :ai_request_metrics, :feature
    add_index :ai_request_metrics, :created_at
    add_index :ai_request_metrics, :cache_hit
    add_index :ai_request_metrics, [ :account_id, :feature, :created_at ], name: "idx_ai_metrics_account_feature_time"
  end
end
