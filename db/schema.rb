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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_subtype", null: false
    t.string "account_type", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "account_type", "account_subtype", "name"], name: "idx_on_workspace_id_account_type_account_subtype_na_048f78df10", unique: true
    t.index ["workspace_id", "account_type"], name: "index_accounts_on_workspace_id_and_account_type"
    t.index ["workspace_id"], name: "index_accounts_on_workspace_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
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

  create_table "campaign_channels", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.string "destination_url", null: false
    t.integer "platform", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "platform"], name: "index_campaign_channels_on_campaign_id_and_platform"
    t.index ["campaign_id"], name: "index_campaign_channels_on_campaign_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "status"], name: "index_campaigns_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_campaigns_on_workspace_id"
  end

  create_table "clicks", force: :cascade do |t|
    t.boolean "bot", default: false, null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "occurred_at", null: false
    t.string "ref_code", null: false
    t.string "referrer"
    t.bigint "shortlink_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["shortlink_id", "occurred_at"], name: "index_clicks_on_shortlink_id_and_occurred_at"
    t.index ["shortlink_id"], name: "index_clicks_on_shortlink_id"
  end

  create_table "conversions", force: :cascade do |t|
    t.integer "amount_kobo", null: false
    t.bigint "campaign_id"
    t.integer "confirmation_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "kind", default: 1, null: false
    t.datetime "occurred_at", null: false
    t.bigint "shortlink_id"
    t.integer "source", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["campaign_id"], name: "index_conversions_on_campaign_id"
    t.index ["shortlink_id"], name: "index_conversions_on_shortlink_id"
    t.index ["workspace_id", "created_at"], name: "index_conversions_on_workspace_id_and_created_at"
    t.index ["workspace_id"], name: "index_conversions_on_workspace_id"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["phone"], name: "index_customers_on_phone"
    t.index ["workspace_id"], name: "index_customers_on_workspace_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "entry_date", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "entry_date"], name: "index_journal_entries_on_workspace_id_and_entry_date"
    t.index ["workspace_id"], name: "index_journal_entries_on_workspace_id"
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "credit_kobo", default: 0, null: false
    t.bigint "debit_kobo", default: 0, null: false
    t.bigint "journal_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_journal_entry_lines_on_account_id"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
  end

  create_table "linking_tokens", force: :cascade do |t|
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["token"], name: "index_linking_tokens_on_token", unique: true
    t.index ["workspace_id"], name: "index_linking_tokens_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shortlinks", force: :cascade do |t|
    t.bigint "campaign_channel_id", null: false
    t.datetime "created_at", null: false
    t.string "host", null: false
    t.string "label"
    t.string "ref_code", null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_channel_id"], name: "index_shortlinks_on_campaign_channel_id"
    t.index ["host", "slug"], name: "index_shortlinks_on_host_and_slug", unique: true
    t.index ["ref_code"], name: "index_shortlinks_on_ref_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["workspace_id"], name: "index_users_on_workspace_id"
  end

  create_table "whatsapp_document_extractions", force: :cascade do |t|
    t.integer "amount_kobo"
    t.float "confidence"
    t.datetime "created_at", null: false
    t.string "currency"
    t.boolean "currency_supported", default: false, null: false
    t.integer "direction_guess", default: 0, null: false
    t.integer "document_type", default: 0, null: false
    t.bigint "journal_entry_id"
    t.text "narration"
    t.text "raw_text"
    t.string "recipient_bank"
    t.string "recipient_name"
    t.string "reference_number"
    t.integer "review_status", default: 0, null: false
    t.string "sender_name"
    t.date "transaction_date"
    t.datetime "updated_at", null: false
    t.bigint "whatsapp_message_id", null: false
    t.index ["journal_entry_id"], name: "index_whatsapp_document_extractions_on_journal_entry_id"
    t.index ["whatsapp_message_id"], name: "index_whatsapp_document_extractions_on_whatsapp_message_id", unique: true
  end

  create_table "whatsapp_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_message_at"
    t.datetime "linked_at"
    t.string "phone_number_id"
    t.string "profile_name"
    t.datetime "requested_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "wa_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["wa_id"], name: "idx_whatsapp_links_active_wa_id", unique: true, where: "(status = 1)"
    t.index ["workspace_id"], name: "index_whatsapp_links_on_workspace_id"
  end

  create_table "whatsapp_messages", force: :cascade do |t|
    t.text "body"
    t.integer "classification_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "direction", default: 0, null: false
    t.bigint "matched_shortlink_id"
    t.string "media_id"
    t.integer "media_status", default: 0, null: false
    t.string "message_type", null: false
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.string "wamid", null: false
    t.bigint "whatsapp_link_id"
    t.bigint "workspace_id", null: false
    t.index ["matched_shortlink_id"], name: "index_whatsapp_messages_on_matched_shortlink_id"
    t.index ["wamid"], name: "index_whatsapp_messages_on_wamid", unique: true
    t.index ["whatsapp_link_id"], name: "index_whatsapp_messages_on_whatsapp_link_id"
    t.index ["workspace_id", "sent_at"], name: "index_whatsapp_messages_on_workspace_id_and_sent_at"
    t.index ["workspace_id"], name: "index_whatsapp_messages_on_workspace_id"
  end

  create_table "whatsapp_processed_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wamid", null: false
    t.index ["wamid"], name: "index_whatsapp_processed_messages_on_wamid", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "accounts", "workspaces"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaign_channels", "campaigns"
  add_foreign_key "campaigns", "workspaces"
  add_foreign_key "clicks", "shortlinks"
  add_foreign_key "conversions", "campaigns"
  add_foreign_key "conversions", "shortlinks"
  add_foreign_key "conversions", "workspaces"
  add_foreign_key "customers", "workspaces"
  add_foreign_key "journal_entries", "workspaces"
  add_foreign_key "journal_entry_lines", "accounts"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "linking_tokens", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "shortlinks", "campaign_channels"
  add_foreign_key "users", "workspaces"
  add_foreign_key "whatsapp_document_extractions", "journal_entries"
  add_foreign_key "whatsapp_document_extractions", "whatsapp_messages"
  add_foreign_key "whatsapp_links", "workspaces"
  add_foreign_key "whatsapp_messages", "shortlinks", column: "matched_shortlink_id"
  add_foreign_key "whatsapp_messages", "whatsapp_links"
  add_foreign_key "whatsapp_messages", "workspaces"
end
