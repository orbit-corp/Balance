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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "kind"], name: "index_categories_on_workspace_id_and_kind"
    t.index ["workspace_id"], name: "index_categories_on_workspace_id"
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

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount_kobo", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.integer "kind", null: false
    t.text "note"
    t.date "occurred_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["customer_id"], name: "index_transactions_on_customer_id"
    t.index ["workspace_id", "kind"], name: "index_transactions_on_workspace_id_and_kind"
    t.index ["workspace_id", "occurred_on"], name: "index_transactions_on_workspace_id_and_occurred_on"
    t.index ["workspace_id"], name: "index_transactions_on_workspace_id"
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

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "categories", "workspaces"
  add_foreign_key "customers", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "customers"
  add_foreign_key "transactions", "workspaces"
  add_foreign_key "users", "workspaces"
end
