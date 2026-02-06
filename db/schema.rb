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

ActiveRecord::Schema[8.1].define(version: 2026_02_06_064632) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "subscription_events", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "event_type", null: false
    t.datetime "expires_date"
    t.string "product_id"
    t.datetime "purchase_date"
    t.bigint "subscription_id"
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["subscription_id"], name: "index_subscription_events_on_subscription_id"
    t.index ["transaction_id", "event_type", "purchase_date"], name: "idx_subscription_events_idempotency", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.string "product_id", null: false
    t.string "status", null: false
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["transaction_id"], name: "index_subscriptions_on_transaction_id", unique: true
  end

  add_foreign_key "subscription_events", "subscriptions"
end
