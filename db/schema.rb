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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_140200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "sync_runs", force: :cascade do |t|
    t.integer "modality_id", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "pages", default: 0, null: false
    t.integer "fetched_count", default: 0, null: false
    t.integer "upserted_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["modality_id", "started_at"], name: "index_sync_runs_on_modality_id_and_started_at"
    t.index ["status"], name: "index_sync_runs_on_status"
  end

  create_table "tenders", force: :cascade do |t|
    t.string "pncp_control_number", null: false
    t.integer "year"
    t.integer "sequence"
    t.string "purchase_number"
    t.string "process_number"
    t.integer "modality_id"
    t.string "modality_name"
    t.string "dispute_mode_name"
    t.integer "status_id"
    t.string "status_name"
    t.text "object_description"
    t.text "additional_info"
    t.boolean "price_registration", default: false, null: false
    t.decimal "estimated_value", precision: 15, scale: 4
    t.decimal "awarded_value", precision: 15, scale: 4
    t.datetime "proposals_open_at"
    t.datetime "proposals_close_at"
    t.datetime "published_at"
    t.datetime "source_updated_at"
    t.string "agency_cnpj"
    t.string "agency_name"
    t.string "agency_power"
    t.string "agency_sphere"
    t.string "unit_code"
    t.string "unit_name"
    t.string "ibge_code"
    t.string "city"
    t.string "state"
    t.string "origin_url"
    t.string "pncp_url"
    t.jsonb "raw", default: {}, null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "searchable", type: :tsvector, as: "to_tsvector('portuguese'::regconfig, ((((((COALESCE(object_description, ''::text) || ' '::text) || COALESCE(additional_info, ''::text)) || ' '::text) || (COALESCE(agency_name, ''::character varying))::text) || ' '::text) || (COALESCE(unit_name, ''::character varying))::text))", stored: true
    t.index ["modality_id"], name: "index_tenders_on_modality_id"
    t.index ["pncp_control_number"], name: "index_tenders_on_pncp_control_number", unique: true
    t.index ["proposals_close_at"], name: "index_tenders_on_proposals_close_at"
    t.index ["searchable"], name: "index_tenders_on_searchable", using: :gin
    t.index ["state"], name: "index_tenders_on_state"
    t.index ["status_id"], name: "index_tenders_on_status_id"
  end
end
