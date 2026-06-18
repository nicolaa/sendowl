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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_030349) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "download_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "download_count"
    t.datetime "expires_at"
    t.bigint "order_id", null: false
    t.string "token_hash"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_download_links_on_order_id"
    t.index ["token_hash"], name: "index_download_links_on_token_hash", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.string "buyer_email"
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_orders_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "expiry_hours"
    t.string "file_placeholder"
    t.integer "max_download_count"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "download_links", "orders"
  add_foreign_key "orders", "products"
end
