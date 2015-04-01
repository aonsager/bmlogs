# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150331120243) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bosses", force: :cascade do |t|
    t.string   "name"
    t.string   "zone_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "fights", force: :cascade do |t|
    t.string   "report_id",                  null: false
    t.integer  "fight_id",                   null: false
    t.text     "name"
    t.integer  "boss_id"
    t.integer  "size"
    t.integer  "difficulty"
    t.boolean  "kill"
    t.boolean  "processed",  default: false
    t.integer  "started_at"
    t.integer  "ended_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "fights", ["report_id", "fight_id"], name: "index_fights_on_report_id_and_fight_id", unique: true, using: :btree

  create_table "reports", force: :cascade do |t|
    t.string   "report_id",                  null: false
    t.string   "user_id"
    t.string   "title"
    t.integer  "zone"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.boolean  "imported",   default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "reports", ["report_id"], name: "index_reports_on_report_id", unique: true, using: :btree

  create_table "zones", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
