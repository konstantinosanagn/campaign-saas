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

ActiveRecord::Schema[8.1].define(version: 2025_11_11_045311) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_configs", force: :cascade do |t|
    t.string "agent_name", limit: 50, null: false
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["agent_name"], name: "index_agent_configs_on_agent_name"
    t.index ["campaign_id", "agent_name"], name: "index_agent_configs_on_campaign_id_and_agent_name", unique: true
    t.index ["campaign_id"], name: "index_agent_configs_on_campaign_id"
    t.check_constraint "agent_name::text = ANY (ARRAY['SEARCH'::character varying::text, 'WRITER'::character varying::text, 'DESIGN'::character varying::text, 'CRITIQUE'::character varying::text, 'DESIGNER'::character varying::text, 'SENDER'::character varying::text])", name: "check_agent_configs_agent_name"
    t.check_constraint "enabled = ANY (ARRAY[true, false])", name: "check_agent_configs_enabled"
  end

  create_table "agent_outputs", force: :cascade do |t|
    t.string "agent_name", limit: 50, null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "lead_id", null: false
    t.jsonb "output_data", default: {}, null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_name"], name: "index_agent_outputs_on_agent_name"
    t.index ["lead_id", "agent_name"], name: "index_agent_outputs_on_lead_id_and_agent_name", unique: true
    t.index ["lead_id"], name: "index_agent_outputs_on_lead_id"
    t.check_constraint "agent_name::text = ANY (ARRAY['SEARCH'::character varying::text, 'WRITER'::character varying::text, 'DESIGN'::character varying::text, 'CRITIQUE'::character varying::text, 'DESIGNER'::character varying::text, 'SENDER'::character varying::text])", name: "check_agent_outputs_agent_name"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "check_agent_outputs_status"
  end

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "shared_settings", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "leads", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "quality", default: "-"
    t.string "stage", default: "queued"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["campaign_id"], name: "index_leads_on_campaign_id"
    t.index ["email"], name: "index_leads_on_email"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.text "gmail_access_token"
    t.text "gmail_refresh_token"
    t.datetime "gmail_token_expires_at"
    t.string "llm_api_key"
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "send_from_email"
    t.string "tavily_api_key"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["llm_api_key"], name: "index_users_on_llm_api_key"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tavily_api_key"], name: "index_users_on_tavily_api_key"
  end

  add_foreign_key "agent_configs", "campaigns"
  add_foreign_key "agent_outputs", "leads"
  add_foreign_key "campaigns", "users"
  add_foreign_key "leads", "campaigns"
end
