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

ActiveRecord::Schema[8.0].define(version: 2025_08_08_105829) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "executions", force: :cascade do |t|
    t.bigint "prompt_id", null: false
    t.integer "iterations"
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prompt_id"], name: "index_executions_on_prompt_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.text "system_prompt"
    t.text "user_prompt"
    t.jsonb "parameters"
    t.string "selected_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "results", force: :cascade do |t|
    t.bigint "execution_id", null: false
    t.integer "iteration_number"
    t.text "response_text"
    t.jsonb "tokens_used"
    t.integer "response_time_ms"
    t.string "status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id"], name: "index_results_on_execution_id"
  end

  create_table "templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.text "system_prompt"
    t.text "user_prompt"
    t.jsonb "default_parameters"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "executions", "prompts"
  add_foreign_key "results", "executions"
end
