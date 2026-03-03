# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_02_234214) do
  create_table "access_tokens", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "identity_id", null: false
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.string "name"
    t.integer "permission", default: 0, null: false
    t.datetime "revoked_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_access_tokens_on_expires_at"
    t.index ["identity_id"], name: "index_access_tokens_on_identity_id"
    t.index ["revoked_at"], name: "index_access_tokens_on_revoked_at"
    t.index ["token"], name: "index_access_tokens_on_token", unique: true
  end

  create_table "accesses", id: :string, force: :cascade do |t|
    t.datetime "accessed_at"
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "entity_id", null: false
    t.string "entity_type", null: false
    t.integer "involvement", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["account_id"], name: "index_accesses_on_account_id"
    t.index ["entity_type", "entity_id"], name: "index_accesses_on_entity_type_and_entity_id"
    t.index ["user_id", "entity_type", "entity_id"], name: "index_accesses_on_user_id_and_entity_type_and_entity_id", unique: true
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "account_cancellations", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["account_id"], name: "index_account_cancellations_on_account_id"
    t.index ["user_id"], name: "index_account_cancellations_on_user_id"
  end

  create_table "account_join_codes", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "usage_limit", default: 10000000000, null: false
    t.index ["account_id"], name: "index_account_join_codes_on_account_id"
    t.index ["code"], name: "index_account_join_codes_on_code", unique: true
  end

  create_table "accounts", id: :string, force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "default_daily_calories_target"
    t.string "default_diet_name"
    t.bigint "external_account_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_request_metrics", id: :string, force: :cascade do |t|
    t.string "account_id"
    t.integer "cache_creation_input_tokens", default: 0
    t.boolean "cache_hit", default: false
    t.integer "cache_read_input_tokens", default: 0
    t.datetime "created_at", null: false
    t.float "duration_ms"
    t.string "error_class"
    t.string "error_message"
    t.string "feature", null: false
    t.integer "input_tokens", default: 0
    t.string "method_name", null: false
    t.string "model", null: false
    t.integer "output_tokens", default: 0
    t.datetime "updated_at", null: false
    t.index ["account_id", "feature", "created_at"], name: "idx_ai_metrics_account_feature_time"
    t.index ["account_id"], name: "index_ai_request_metrics_on_account_id"
    t.index ["cache_hit"], name: "index_ai_request_metrics_on_cache_hit"
    t.index ["created_at"], name: "index_ai_request_metrics_on_created_at"
    t.index ["feature"], name: "index_ai_request_metrics_on_feature"
  end

  create_table "ai_task_statuses", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.integer "progress_percentage", default: 0, null: false
    t.json "result"
    t.integer "status", default: 0, null: false
    t.string "task_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_ai_task_statuses_on_account_id_and_status"
    t.index ["account_id"], name: "index_ai_task_statuses_on_account_id"
  end

  create_table "dietary_profiles", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "daily_calories_target"
    t.string "diet_name"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.index ["account_id", "name"], name: "index_dietary_profiles_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_dietary_profiles_on_account_id"
    t.index ["user_id"], name: "index_dietary_profiles_on_user_id"
  end

  create_table "identities", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "staff", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
  end

  create_table "ingredients", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0
    t.string "name", null: false
    t.string "nutrition_item_id"
    t.string "quantity"
    t.string "recipe_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["nutrition_item_id"], name: "index_ingredients_on_nutrition_item_id"
    t.index ["recipe_id", "display_order"], name: "index_ingredients_on_recipe_id_and_display_order"
    t.index ["recipe_id"], name: "index_ingredients_on_recipe_id"
  end

  create_table "invitations", id: :string, force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at", null: false
    t.string "invited_by_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email_address"], name: "index_invitations_on_account_id_and_email_address"
    t.index ["account_id"], name: "index_invitations_on_account_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "magic_links", id: :string, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "identity_id", null: false
    t.integer "purpose", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["identity_id"], name: "index_magic_links_on_identity_id"
  end

  create_table "meal_plan_days", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "day_number", null: false
    t.string "meal_plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_id", "date"], name: "index_meal_plan_days_on_meal_plan_id_and_date", unique: true
    t.index ["meal_plan_id", "day_number"], name: "index_meal_plan_days_on_meal_plan_id_and_day_number", unique: true
    t.index ["meal_plan_id"], name: "index_meal_plan_days_on_meal_plan_id"
  end

  create_table "meal_plan_meal_portions", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "meal_plan_meal_id", null: false
    t.string "meal_plan_participant_id", null: false
    t.decimal "servings", precision: 4, scale: 2, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_meal_id", "meal_plan_participant_id"], name: "idx_meal_portions_unique", unique: true
    t.index ["meal_plan_meal_id"], name: "index_meal_plan_meal_portions_on_meal_plan_meal_id"
    t.index ["meal_plan_participant_id"], name: "index_meal_plan_meal_portions_on_meal_plan_participant_id"
  end

  create_table "meal_plan_meals", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "meal_plan_day_id", null: false
    t.integer "meal_type", null: false
    t.string "recipe_id", null: false
    t.decimal "servings", precision: 4, scale: 2, default: "1.0"
    t.datetime "updated_at", null: false
    t.index ["meal_plan_day_id", "meal_type"], name: "index_meal_plan_meals_on_meal_plan_day_id_and_meal_type"
    t.index ["meal_plan_day_id"], name: "index_meal_plan_meals_on_meal_plan_day_id"
    t.index ["recipe_id"], name: "index_meal_plan_meals_on_recipe_id"
  end

  create_table "meal_plan_participants", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dietary_profile_id", null: false
    t.string "meal_plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dietary_profile_id"], name: "index_meal_plan_participants_on_dietary_profile_id"
    t.index ["meal_plan_id", "dietary_profile_id"], name: "idx_meal_plan_participants_unique", unique: true
    t.index ["meal_plan_id"], name: "index_meal_plan_participants_on_meal_plan_id"
  end

  create_table "meal_plans", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "daily_calories_target"
    t.date "end_date", null: false
    t.string "name"
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["account_id", "start_date"], name: "index_meal_plans_on_account_id_and_start_date"
    t.index ["account_id"], name: "index_meal_plans_on_account_id"
    t.index ["user_id"], name: "index_meal_plans_on_user_id"
  end

  create_table "nutrition_item_aliases", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "nutrition_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_nutrition_item_aliases_on_name", unique: true
    t.index ["nutrition_item_id"], name: "index_nutrition_item_aliases_on_nutrition_item_id"
  end

  create_table "nutrition_item_portions", id: :string, force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.decimal "gram_weight", precision: 10, scale: 2, null: false
    t.string "nutrition_item_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["nutrition_item_id", "unit"], name: "index_nutrition_item_portions_on_item_and_unit"
    t.index ["nutrition_item_id"], name: "index_nutrition_item_portions_on_nutrition_item_id"
  end

  create_table "nutrition_items", id: :string, force: :cascade do |t|
    t.integer "calories"
    t.decimal "carbs", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.decimal "fat", precision: 8, scale: 2
    t.integer "fdc_id", null: false
    t.decimal "fiber", precision: 8, scale: 2
    t.integer "magnesium"
    t.boolean "portions_fetched", default: false
    t.integer "potassium"
    t.decimal "protein", precision: 8, scale: 2
    t.integer "sodium"
    t.datetime "updated_at", null: false
    t.index ["fdc_id"], name: "index_nutrition_items_on_fdc_id", unique: true
  end

  create_table "pending_recipe_transfers", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identity_id", null: false
    t.string "source_recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id", "source_recipe_id"], name: "idx_on_identity_id_source_recipe_id_d424db4ece", unique: true
    t.index ["identity_id"], name: "index_pending_recipe_transfers_on_identity_id"
  end

  create_table "recipe_instructions", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instruction", null: false
    t.string "recipe_id", null: false
    t.integer "step_number", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "step_number"], name: "index_recipe_instructions_on_recipe_id_and_step_number", unique: true
    t.index ["recipe_id"], name: "index_recipe_instructions_on_recipe_id"
  end

  create_table "recipe_nutrition_data", id: :string, force: :cascade do |t|
    t.boolean "auto_calculated", default: false, null: false
    t.integer "calories"
    t.decimal "carbs", precision: 6, scale: 1
    t.datetime "created_at", null: false
    t.json "diet_scores"
    t.decimal "fat", precision: 6, scale: 1
    t.decimal "fiber", precision: 6, scale: 1
    t.integer "magnesium"
    t.decimal "net_carbs", precision: 6, scale: 1
    t.integer "potassium"
    t.decimal "protein", precision: 6, scale: 1
    t.string "recipe_id", null: false
    t.integer "sodium"
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_nutrition_data_on_recipe_id"
  end

  create_table "recipe_tags", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "recipe_id", null: false
    t.string "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "tag_id"], name: "index_recipe_tags_on_recipe_id_and_tag_id", unique: true
  end

  create_table "recipe_tips", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "recipe_id", null: false
    t.text "tip", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_tips_on_recipe_id"
  end

  create_table "recipes", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.integer "category", default: 0, null: false
    t.integer "cook_time"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "forked_from_id"
    t.integer "prep_time"
    t.integer "rating"
    t.integer "servings"
    t.string "source"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "category"], name: "index_recipes_on_account_id_and_category"
    t.index ["account_id", "rating"], name: "index_recipes_on_account_id_and_rating"
    t.index ["account_id", "title"], name: "index_recipes_on_account_id_and_title"
    t.index ["account_id"], name: "index_recipes_on_account_id"
    t.index ["forked_from_id"], name: "index_recipes_on_forked_from_id"
  end

  create_table "sessions", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "identity_id", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  create_table "shopping_list_items", id: :string, force: :cascade do |t|
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "quantity"
    t.string "shopping_list_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["shopping_list_id"], name: "index_shopping_list_items_on_shopping_list_id"
  end

  create_table "shopping_lists", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "meal_plan_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["account_id"], name: "index_shopping_lists_on_account_id"
    t.index ["meal_plan_id"], name: "index_shopping_lists_on_meal_plan_id"
    t.index ["user_id"], name: "index_shopping_lists_on_user_id"
  end

  create_table "tags", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_tags_on_account_id_and_name", unique: true
  end

  create_table "user_settings", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "email_frequency", default: 0, null: false
    t.string "timezone"
    t.integer "unit_system", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "identity_id"
    t.string "name", null: false
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["account_id", "identity_id"], name: "index_users_on_account_id_and_identity_id", unique: true, where: "identity_id IS NOT NULL"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end

  add_foreign_key "access_tokens", "identities"
  add_foreign_key "accesses", "accounts"
  add_foreign_key "accesses", "users"
  add_foreign_key "account_cancellations", "accounts"
  add_foreign_key "account_cancellations", "users"
  add_foreign_key "account_join_codes", "accounts"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_request_metrics", "accounts"
  add_foreign_key "ai_task_statuses", "accounts"
  add_foreign_key "dietary_profiles", "accounts"
  add_foreign_key "dietary_profiles", "users"
  add_foreign_key "ingredients", "nutrition_items"
  add_foreign_key "ingredients", "recipes"
  add_foreign_key "magic_links", "identities"
  add_foreign_key "meal_plan_days", "meal_plans"
  add_foreign_key "meal_plan_meal_portions", "meal_plan_meals"
  add_foreign_key "meal_plan_meal_portions", "meal_plan_participants"
  add_foreign_key "meal_plan_meals", "meal_plan_days"
  add_foreign_key "meal_plan_meals", "recipes"
  add_foreign_key "meal_plan_participants", "dietary_profiles"
  add_foreign_key "meal_plan_participants", "meal_plans"
  add_foreign_key "meal_plans", "accounts"
  add_foreign_key "meal_plans", "users"
  add_foreign_key "nutrition_item_aliases", "nutrition_items"
  add_foreign_key "nutrition_item_portions", "nutrition_items"
  add_foreign_key "recipe_instructions", "recipes"
  add_foreign_key "recipe_nutrition_data", "recipes"
  add_foreign_key "recipe_tags", "recipes"
  add_foreign_key "recipe_tags", "tags"
  add_foreign_key "recipe_tips", "recipes"
  add_foreign_key "recipes", "accounts"
  add_foreign_key "sessions", "identities"
  add_foreign_key "shopping_list_items", "shopping_lists"
  add_foreign_key "shopping_lists", "accounts"
  add_foreign_key "shopping_lists", "meal_plans"
  add_foreign_key "shopping_lists", "users"
  add_foreign_key "tags", "accounts"
  add_foreign_key "user_settings", "users"
  add_foreign_key "users", "accounts"
  add_foreign_key "users", "identities"
end
