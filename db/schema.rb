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

ActiveRecord::Schema[8.1].define(version: 2026_08_27_000300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.string "base_type", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "detail_type", null: false
    t.string "name", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "account_type"], name: "index_accounts_on_workspace_id_and_account_type"
    t.index ["workspace_id", "base_type"], name: "index_accounts_on_workspace_id_and_base_type"
    t.index ["workspace_id", "name"], name: "index_accounts_on_workspace_id_and_name", unique: true
    t.index ["workspace_id", "role"], name: "index_accounts_on_workspace_id_and_role", unique: true, where: "(role IS NOT NULL)"
    t.index ["workspace_id"], name: "index_accounts_on_workspace_id"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_customers_on_workspace_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "entry_date", null: false
    t.bigint "reverses_journal_entry_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["reverses_journal_entry_id"], name: "index_journal_entries_on_reverses_journal_entry_id"
    t.index ["workspace_id", "entry_date"], name: "index_journal_entries_on_workspace_id_and_entry_date"
    t.index ["workspace_id"], name: "index_journal_entries_on_workspace_id"
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "counterparty_id"
    t.string "counterparty_type"
    t.datetime "created_at", null: false
    t.bigint "credit_kobo", default: 0, null: false
    t.bigint "debit_kobo", default: 0, null: false
    t.bigint "journal_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_journal_entry_lines_on_account_id"
    t.index ["counterparty_type", "counterparty_id"], name: "index_journal_entry_lines_on_counterparty"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
  end

  create_table "llm_activities", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.bigint "llm_chat_id", null: false
    t.bigint "turn_user_message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id", "turn_user_message_id", "kind"], name: "index_llm_activities_on_turn_and_kind", unique: true
    t.index ["llm_chat_id"], name: "index_llm_activities_on_llm_chat_id"
  end

  create_table "llm_chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "llm_model_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "workspace_id", null: false
    t.index ["llm_model_id"], name: "index_llm_chats_on_llm_model_id"
    t.index ["uuid"], name: "index_llm_chats_on_uuid", unique: true
    t.index ["workspace_id"], name: "index_llm_chats_on_workspace_id"
  end

  create_table "llm_messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_model_id"
    t.bigint "llm_tool_call_id"
    t.bigint "llm_turn_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.datetime "summarized_at"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id"], name: "index_llm_messages_on_llm_chat_id"
    t.index ["llm_model_id"], name: "index_llm_messages_on_llm_model_id"
    t.index ["llm_tool_call_id"], name: "index_llm_messages_on_llm_tool_call_id"
    t.index ["llm_turn_id"], name: "index_llm_messages_on_llm_turn_id"
    t.index ["role"], name: "index_llm_messages_on_role"
  end

  create_table "llm_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_llm_models_on_family"
    t.index ["modalities"], name: "index_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_llm_models_on_provider"
  end

  create_table "llm_tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "llm_message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.jsonb "trace_output", default: {}, null: false
    t.string "trace_status"
    t.datetime "updated_at", null: false
    t.index ["llm_message_id"], name: "index_llm_tool_calls_on_llm_message_id"
    t.index ["name"], name: "index_llm_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "llm_transaction_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "facts", default: {}, null: false
    t.bigint "last_question_message_id"
    t.bigint "llm_chat_id", null: false
    t.jsonb "source_message_ids", default: [], null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id", "status"], name: "index_llm_transaction_sessions_on_llm_chat_id_and_status"
    t.index ["llm_chat_id"], name: "index_llm_transaction_sessions_on_llm_chat_id"
  end

  create_table "llm_turns", force: :cascade do |t|
    t.jsonb "allowed_tools", default: [], null: false
    t.jsonb "classification", default: {}, null: false
    t.datetime "completed_at"
    t.jsonb "context_message_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.text "error"
    t.string "intent"
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_transaction_session_id"
    t.string "relationship"
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_message_id", null: false
    t.index ["llm_chat_id", "status"], name: "index_llm_turns_on_llm_chat_id_and_status"
    t.index ["llm_chat_id"], name: "index_llm_turns_on_llm_chat_id"
    t.index ["llm_transaction_session_id"], name: "index_llm_turns_on_llm_transaction_session_id"
    t.index ["user_message_id"], name: "index_llm_turns_on_user_message_id", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "proposals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "journal_entry_id"
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_message_id"
    t.string "proposal_type", null: false
    t.string "status", default: "proposed", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.bigint "workspace_id", null: false
    t.index ["journal_entry_id"], name: "index_proposals_on_journal_entry_id"
    t.index ["llm_chat_id", "proposal_type", "version"], name: "index_proposals_on_llm_chat_id_and_proposal_type_and_version"
    t.index ["llm_chat_id"], name: "index_proposals_on_llm_chat_id"
    t.index ["llm_message_id"], name: "index_proposals_on_llm_message_id"
    t.index ["workspace_id", "status"], name: "index_proposals_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_proposals_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.bigint "workspace_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.index ["workspace_id"], name: "index_sessions_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "full_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.datetime "updated_at", null: false
    t.string "workspace_type", default: "personal", null: false
  end

  add_foreign_key "accounts", "workspaces"
  add_foreign_key "customers", "workspaces"
  add_foreign_key "journal_entries", "journal_entries", column: "reverses_journal_entry_id"
  add_foreign_key "journal_entries", "workspaces"
  add_foreign_key "journal_entry_lines", "accounts"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "llm_activities", "llm_chats"
  add_foreign_key "llm_chats", "llm_models"
  add_foreign_key "llm_chats", "workspaces"
  add_foreign_key "llm_messages", "llm_chats"
  add_foreign_key "llm_messages", "llm_models"
  add_foreign_key "llm_messages", "llm_tool_calls"
  add_foreign_key "llm_messages", "llm_turns"
  add_foreign_key "llm_tool_calls", "llm_messages"
  add_foreign_key "llm_transaction_sessions", "llm_chats"
  add_foreign_key "llm_transaction_sessions", "llm_messages", column: "last_question_message_id"
  add_foreign_key "llm_turns", "llm_chats"
  add_foreign_key "llm_turns", "llm_messages", column: "user_message_id"
  add_foreign_key "llm_turns", "llm_transaction_sessions"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "proposals", "journal_entries"
  add_foreign_key "proposals", "llm_chats"
  add_foreign_key "proposals", "llm_messages"
  add_foreign_key "proposals", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "workspaces"
end
