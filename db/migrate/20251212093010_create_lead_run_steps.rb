class CreateLeadRunSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :lead_run_steps do |t|
      t.references :lead_run, null: false, foreign_key: true

      t.integer :position, null: false
      t.string :agent_name, null: false, limit: 50
      t.string :status, null: false, limit: 20, default: "queued"

      t.references :agent_output, null: true, foreign_key: true
      t.jsonb :meta, null: false, default: {}

      t.datetime :step_started_at
      t.datetime :step_finished_at

      t.timestamps
    end

    add_index :lead_run_steps, [ :lead_run_id, :position ], unique: true, name: "index_lead_run_steps_on_run_and_position"
    add_index :lead_run_steps, [ :lead_run_id, :status, :position ], name: "index_lead_run_steps_next_by_status_position"
    add_index :lead_run_steps, [ :lead_run_id, :agent_name ], name: "index_lead_run_steps_on_run_and_agent_name"

    add_check_constraint :lead_run_steps,
                         "status IN ('queued','running','completed','failed')",
                         name: "check_lead_run_steps_status"

    # Keep agent_name aligned with other tables' allowed set.
    add_check_constraint :lead_run_steps,
                         "agent_name IN ('SEARCH','WRITER','CRITIQUE','DESIGN','DESIGNER','SENDER')",
                         name: "check_lead_run_steps_agent_name"
  end
end
