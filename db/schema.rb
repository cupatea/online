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

ActiveRecord::Schema[8.1].define(version: 2026_07_17_150000) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "name"], name: "index_categories_on_profile_id_and_name", unique: true
    t.index ["profile_id"], name: "index_categories_on_profile_id"
  end

  create_table "links", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "enabled", default: true, null: false
    t.string "icon"
    t.integer "position"
    t.integer "profile_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["category_id"], name: "index_links_on_category_id"
    t.index ["profile_id"], name: "index_links_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_profiles_on_slug", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.string "category", default: "general", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "enabled", default: true, null: false
    t.string "hostname", null: false
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "upstream_host", default: "localhost", null: false
    t.integer "upstream_port", null: false
    t.index ["hostname"], name: "index_services_on_hostname", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "acme_email", default: "", null: false
    t.string "admin_password_digest"
    t.text "base_domains", default: "", null: false
    t.string "cloudflare_token", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "upstream_hosts", default: "", null: false
  end

  add_foreign_key "categories", "profiles"
  add_foreign_key "links", "categories"
  add_foreign_key "links", "profiles"
end
