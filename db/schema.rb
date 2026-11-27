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

ActiveRecord::Schema[8.1].define(version: 2026_11_27_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_hint", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "saved_search_id", null: false
    t.bigint "tender_id", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["saved_search_id", "tender_id"], name: "index_notifications_on_saved_search_id_and_tender_id", unique: true
    t.index ["tender_id"], name: "index_notifications_on_tender_id"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "query"
    t.jsonb "filters", default: {}, null: false
    t.string "niche_slug"
    t.boolean "active", default: true, null: false
    t.boolean "notify_daily", default: true, null: false
    t.datetime "last_notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_saved_searches_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

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
    t.integer "attempt", default: 1, null: false
    t.index ["modality_id", "started_at"], name: "index_sync_runs_on_modality_id_and_started_at"
    t.index ["status"], name: "index_sync_runs_on_status"
  end

  create_table "tender_documents", force: :cascade do |t|
    t.bigint "tender_id", null: false
    t.integer "sequence", null: false
    t.string "title", null: false
    t.integer "type_id"
    t.string "type_name"
    t.string "url"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tender_id", "sequence"], name: "index_tender_documents_on_tender_id_and_sequence", unique: true
  end

  create_table "tender_items", force: :cascade do |t|
    t.bigint "tender_id", null: false
    t.integer "number", null: false
    t.text "description"
    t.string "material_or_service"
    t.decimal "quantity", precision: 18, scale: 4
    t.string "unit"
    t.decimal "unit_estimated_value", precision: 18, scale: 4
    t.decimal "total_estimated_value", precision: 18, scale: 4
    t.boolean "confidential_budget", default: false, null: false
    t.string "status_name"
    t.string "judgment_criterion_name"
    t.string "benefit_name"
    t.string "category_name"
    t.datetime "source_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tender_id", "number"], name: "index_tender_items_on_tender_id_and_number", unique: true
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
    t.datetime "details_fetched_at"
    t.datetime "details_source_updated_at"
    t.datetime "details_requested_at"
    t.text "items_text"
    t.virtual "searchable", type: :tsvector, as: "(setweight(to_tsvector('portuguese'::regconfig, translate(((((((COALESCE(object_description, ''::text) || ' '::text) || COALESCE(additional_info, ''::text)) || ' '::text) || (COALESCE(agency_name, ''::character varying))::text) || ' '::text) || (COALESCE(unit_name, ''::character varying))::text), 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'::text, 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'::text)), 'A'::\"char\") || setweight(to_tsvector('portuguese'::regconfig, translate(COALESCE(items_text, ''::text), 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'::text, 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'::text)), 'D'::\"char\"))", stored: true
    t.index ["modality_id"], name: "index_tenders_on_modality_id"
    t.index ["pncp_control_number"], name: "index_tenders_on_pncp_control_number", unique: true
    t.index ["proposals_close_at"], name: "index_tenders_on_proposals_close_at"
    t.index ["searchable"], name: "index_tenders_on_searchable", using: :gin
    t.index ["state"], name: "index_tenders_on_state"
    t.index ["status_id"], name: "index_tenders_on_status_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "confirmed_at"
    t.string "unconfirmed_email"
    t.integer "deadline_reminder_days", default: 3, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "watches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tender_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "reminded_close_at"
    t.datetime "reminded_at"
    t.text "note"
    t.index ["tender_id"], name: "index_watches_on_tender_id"
    t.index ["user_id", "tender_id"], name: "index_watches_on_user_id_and_tender_id", unique: true
  end

  add_foreign_key "api_tokens", "users", on_delete: :cascade
  add_foreign_key "notifications", "saved_searches", on_delete: :cascade
  add_foreign_key "notifications", "tenders", on_delete: :cascade
  add_foreign_key "saved_searches", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tender_documents", "tenders", on_delete: :cascade
  add_foreign_key "tender_items", "tenders", on_delete: :cascade
  add_foreign_key "watches", "tenders", on_delete: :cascade
  add_foreign_key "watches", "users", on_delete: :cascade
end
