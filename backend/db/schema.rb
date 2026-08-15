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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "encounter_tags", force: :cascade do |t|
    t.bigint "encounter_id", null: false
    t.bigint "tag_id", null: false
    t.index ["encounter_id", "tag_id"], name: "index_encounter_tags_on_encounter_id_and_tag_id", unique: true
  end

  create_table "encounters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "memo"
    t.datetime "met_at", null: false
    t.bigint "person_id", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["person_id", "met_at"], name: "index_encounters_on_person_id_and_met_at"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_encountered_at"
    t.string "name", null: false
    t.text "note", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["last_encountered_at"], name: "index_people_on_last_encountered_at"
  end

  create_table "reminders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.date "remind_on", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_reminders_on_person_id"
    t.index ["remind_on"], name: "index_reminders_on_remind_on", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  add_foreign_key "encounter_tags", "encounters"
  add_foreign_key "encounter_tags", "tags"
  add_foreign_key "encounters", "people"
  add_foreign_key "reminders", "people"
end
