class AddLeadRunRefsToAgentOutputs < ActiveRecord::Migration[8.1]
  def change
    add_reference :agent_outputs, :lead_run, null: true, foreign_key: true
    add_reference :agent_outputs, :lead_run_step, null: true, foreign_key: true

    add_index :agent_outputs, :lead_run_step_id, unique: true, name: "index_agent_outputs_unique_on_lead_run_step_id"
  end
end
