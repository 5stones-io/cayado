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

ActiveRecord::Schema[7.2].define(version: 2026_11_23_000003) do
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

  create_table "cayado_activity_events", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.bigint "actor_membership_id"
    t.string "kind", null: false
    t.bigint "sermon_series_id"
    t.bigint "sermon_week_id"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_membership_id"], name: "index_cayado_activity_events_on_actor_membership_id"
    t.index ["church_id", "id"], name: "index_cayado_activity_events_on_church_id_and_id"
    t.index ["sermon_series_id"], name: "index_cayado_activity_events_on_sermon_series_id"
    t.index ["sermon_week_id"], name: "index_cayado_activity_events_on_sermon_week_id"
  end

  create_table "cayado_alignment_plans", force: :cascade do |t|
    t.bigint "sermon_week_id", null: false
    t.bigint "ministry_id", null: false
    t.text "body", null: false
    t.string "memory_verse"
    t.bigint "updated_by_membership_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ministry_id"], name: "index_cayado_alignment_plans_on_ministry_id"
    t.index ["sermon_week_id", "ministry_id"], name: "index_cayado_alignment_plans_on_sermon_week_id_and_ministry_id", unique: true
    t.index ["updated_by_membership_id"], name: "index_cayado_alignment_plans_on_updated_by_membership_id"
  end

  create_table "cayado_attachments", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "attachable_type", null: false
    t.bigint "attachable_id", null: false
    t.string "title", null: false
    t.string "url", null: false
    t.string "kind", default: "doc", null: false
    t.bigint "owner_membership_id"
    t.text "tags", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_cayado_attachments_on_attachable"
    t.index ["church_id"], name: "index_cayado_attachments_on_church_id"
    t.index ["owner_membership_id"], name: "index_cayado_attachments_on_owner_membership_id"
  end

  create_table "cayado_budgets", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.integer "year", null: false
    t.bigint "monthly_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "year"], name: "index_cayado_budgets_on_church_id_and_year", unique: true
  end

  create_table "cayado_comments", force: :cascade do |t|
    t.bigint "sermon_week_id", null: false
    t.bigint "membership_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_cayado_comments_on_membership_id"
    t.index ["sermon_week_id"], name: "index_cayado_comments_on_sermon_week_id"
  end

  create_table "cayado_congregation_snapshots", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.date "taken_on", null: false
    t.integer "households"
    t.jsonb "life_stages", default: [], null: false
    t.jsonb "season_markers", default: [], null: false
    t.text "note"
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "taken_on"], name: "index_cayado_congregation_snapshots_on_church_id_and_taken_on"
  end

  create_table "cayado_horizon_years", force: :cascade do |t|
    t.bigint "vision_id", null: false
    t.integer "year", null: false
    t.string "headline"
    t.text "goals", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vision_id", "year"], name: "index_cayado_horizon_years_on_vision_id_and_year", unique: true
  end

  create_table "cayado_ministries", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "color", default: "ink", null: false
    t.bigint "lead_membership_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "key"], name: "index_cayado_ministries_on_church_id_and_key", unique: true
    t.index ["lead_membership_id"], name: "index_cayado_ministries_on_lead_membership_id"
  end

  create_table "cayado_moves", force: :cascade do |t|
    t.bigint "pillar_id", null: false
    t.integer "position", default: 0, null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pillar_id"], name: "index_cayado_moves_on_pillar_id"
  end

  create_table "cayado_pillar_editors", force: :cascade do |t|
    t.bigint "pillar_id", null: false
    t.bigint "membership_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_cayado_pillar_editors_on_membership_id"
    t.index ["pillar_id", "membership_id"], name: "index_cayado_pillar_editors_on_pillar_id_and_membership_id", unique: true
  end

  create_table "cayado_pillars", force: :cascade do |t|
    t.bigint "vision_id", null: false
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.text "blurb"
    t.string "tone", default: "ink", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vision_id"], name: "index_cayado_pillars_on_vision_id"
  end

  create_table "cayado_roadmap_items", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "lane", null: false
    t.string "title", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.string "color", default: "ink", null: false
    t.bigint "owner_membership_id"
    t.text "notes"
    t.bigint "pillar_id"
    t.bigint "move_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "starts_on"], name: "index_cayado_roadmap_items_on_church_id_and_starts_on"
    t.index ["move_id"], name: "index_cayado_roadmap_items_on_move_id"
    t.index ["owner_membership_id"], name: "index_cayado_roadmap_items_on_owner_membership_id"
    t.index ["pillar_id"], name: "index_cayado_roadmap_items_on_pillar_id"
  end

  create_table "cayado_series_topics", force: :cascade do |t|
    t.bigint "sermon_series_id", null: false
    t.bigint "topic_id", null: false
    t.integer "weight", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sermon_series_id", "topic_id"], name: "index_cayado_series_topics_on_sermon_series_id_and_topic_id", unique: true
    t.index ["topic_id"], name: "index_cayado_series_topics_on_topic_id"
    t.check_constraint "weight >= 1 AND weight <= 3", name: "series_topic_weight_1_to_3"
  end

  create_table "cayado_sermon_series", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "title", null: false
    t.string "theme"
    t.string "scripture"
    t.date "starts_on"
    t.date "ends_on"
    t.bigint "owner_membership_id"
    t.bigint "move_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_cayado_sermon_series_on_church_id"
    t.index ["move_id"], name: "index_cayado_sermon_series_on_move_id"
    t.index ["owner_membership_id"], name: "index_cayado_sermon_series_on_owner_membership_id"
  end

  create_table "cayado_sermon_weeks", force: :cascade do |t|
    t.bigint "sermon_series_id", null: false
    t.integer "position", default: 0, null: false
    t.date "preached_on", null: false
    t.string "title"
    t.string "scripture"
    t.text "big_idea"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "congregation_snapshot_id"
    t.index ["congregation_snapshot_id"], name: "index_cayado_sermon_weeks_on_congregation_snapshot_id"
    t.index ["preached_on"], name: "index_cayado_sermon_weeks_on_preached_on"
    t.index ["sermon_series_id"], name: "index_cayado_sermon_weeks_on_sermon_series_id"
  end

  create_table "cayado_topics", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "name"], name: "index_cayado_topics_on_church_id_and_name", unique: true
  end

  create_table "cayado_visions", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "title", null: false
    t.string "subtitle"
    t.integer "start_year", null: false
    t.integer "end_year", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_cayado_visions_on_church_id", unique: true
  end

  create_table "cayado_weekly_metrics", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.date "week_of", null: false
    t.integer "attendance"
    t.integer "first_time_guests"
    t.bigint "giving_cents"
    t.jsonb "by_ministry", default: [], null: false
    t.string "label"
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "week_of"], name: "index_cayado_weekly_metrics_on_church_id_and_week_of", unique: true
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
    t.datetime "activity_seen_at"
    t.index ["account_id", "church_id"], name: "index_memberships_on_account_id_and_church_id", unique: true
    t.index ["church_id"], name: "index_memberships_on_church_id"
  end

  add_foreign_key "account_lockouts", "accounts", column: "id"
  add_foreign_key "account_login_failures", "accounts", column: "id"
  add_foreign_key "account_otp_keys", "accounts", column: "id"
  add_foreign_key "account_password_codes", "accounts", column: "id"
  add_foreign_key "account_password_hashes", "accounts", column: "id"
  add_foreign_key "account_recovery_codes", "accounts", column: "id"
  add_foreign_key "cayado_activity_events", "cayado_sermon_series", column: "sermon_series_id", on_delete: :cascade
  add_foreign_key "cayado_activity_events", "cayado_sermon_weeks", column: "sermon_week_id", on_delete: :cascade
  add_foreign_key "cayado_activity_events", "churches"
  add_foreign_key "cayado_activity_events", "memberships", column: "actor_membership_id", on_delete: :nullify
  add_foreign_key "cayado_alignment_plans", "cayado_ministries", column: "ministry_id"
  add_foreign_key "cayado_alignment_plans", "cayado_sermon_weeks", column: "sermon_week_id"
  add_foreign_key "cayado_alignment_plans", "memberships", column: "updated_by_membership_id", on_delete: :nullify
  add_foreign_key "cayado_attachments", "churches"
  add_foreign_key "cayado_attachments", "memberships", column: "owner_membership_id", on_delete: :nullify
  add_foreign_key "cayado_budgets", "churches"
  add_foreign_key "cayado_comments", "cayado_sermon_weeks", column: "sermon_week_id"
  add_foreign_key "cayado_comments", "memberships", on_delete: :nullify
  add_foreign_key "cayado_congregation_snapshots", "churches"
  add_foreign_key "cayado_horizon_years", "cayado_visions", column: "vision_id"
  add_foreign_key "cayado_ministries", "churches"
  add_foreign_key "cayado_ministries", "memberships", column: "lead_membership_id", on_delete: :nullify
  add_foreign_key "cayado_moves", "cayado_pillars", column: "pillar_id"
  add_foreign_key "cayado_pillar_editors", "cayado_pillars", column: "pillar_id"
  add_foreign_key "cayado_pillar_editors", "memberships", on_delete: :cascade
  add_foreign_key "cayado_pillars", "cayado_visions", column: "vision_id"
  add_foreign_key "cayado_roadmap_items", "cayado_moves", column: "move_id", on_delete: :nullify
  add_foreign_key "cayado_roadmap_items", "cayado_pillars", column: "pillar_id", on_delete: :nullify
  add_foreign_key "cayado_roadmap_items", "churches"
  add_foreign_key "cayado_roadmap_items", "memberships", column: "owner_membership_id", on_delete: :nullify
  add_foreign_key "cayado_series_topics", "cayado_sermon_series", column: "sermon_series_id", on_delete: :cascade
  add_foreign_key "cayado_series_topics", "cayado_topics", column: "topic_id", on_delete: :cascade
  add_foreign_key "cayado_sermon_series", "cayado_moves", column: "move_id", on_delete: :nullify
  add_foreign_key "cayado_sermon_series", "churches"
  add_foreign_key "cayado_sermon_series", "memberships", column: "owner_membership_id", on_delete: :nullify
  add_foreign_key "cayado_sermon_weeks", "cayado_congregation_snapshots", column: "congregation_snapshot_id", on_delete: :nullify
  add_foreign_key "cayado_sermon_weeks", "cayado_sermon_series", column: "sermon_series_id"
  add_foreign_key "cayado_topics", "churches"
  add_foreign_key "cayado_visions", "churches"
  add_foreign_key "cayado_weekly_metrics", "churches"
  add_foreign_key "custom_domains", "churches"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "churches"
end
