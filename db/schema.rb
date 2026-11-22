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

ActiveRecord::Schema[7.2].define(version: 2026_11_22_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "account_lockouts", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
    t.datetime "email_last_sent"
  end

  create_table "account_login_failures", force: :cascade do |t|
    t.integer "number", default: 1, null: false
  end

  create_table "account_otp_keys", force: :cascade do |t|
    t.string "key", null: false
    t.integer "num_failures", default: 0, null: false
    t.datetime "last_use", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "account_password_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "deadline", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "account_password_hashes", force: :cascade do |t|
    t.string "password_hash", null: false
  end

  create_table "account_recovery_codes", primary_key: ["id", "code"], force: :cascade do |t|
    t.bigint "id", null: false
    t.string "code", null: false
  end

  create_table "accounts", force: :cascade do |t|
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "status_id", default: 2, null: false
    t.boolean "platform_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true, where: "(status_id <> 3)"
  end

  create_table "churches", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "display_name"
    t.string "status", default: "pending", null: false
    t.string "timezone"
    t.string "city"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_churches_on_slug", unique: true
  end

  create_table "custom_domains", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "hostname", null: false
    t.datetime "verified_at"
    t.string "verification_token", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_custom_domains_on_church_id"
    t.index ["hostname"], name: "index_custom_domains_on_hostname", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "church_id", null: false
    t.string "role", default: "member", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "church_id"], name: "index_memberships_on_account_id_and_church_id", unique: true
    t.index ["church_id"], name: "index_memberships_on_church_id"
  end

  add_foreign_key "account_lockouts", "accounts", column: "id"
  add_foreign_key "account_login_failures", "accounts", column: "id"
  add_foreign_key "account_otp_keys", "accounts", column: "id"
  add_foreign_key "account_password_codes", "accounts", column: "id"
  add_foreign_key "account_password_hashes", "accounts", column: "id"
  add_foreign_key "account_recovery_codes", "accounts", column: "id"
  add_foreign_key "custom_domains", "churches"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "churches"
end
