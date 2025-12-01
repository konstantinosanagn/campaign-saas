class RemoveUniqueConstraintFromAgentOutputs < ActiveRecord::Migration[8.1]
  def up
    # Remove the unique constraint to allow multiple outputs per agent per lead
    remove_index :agent_outputs, name: 'index_agent_outputs_on_lead_id_and_agent_name'

    # Add a non-unique index for performance (queries by lead_id and agent_name)
    add_index :agent_outputs, [ :lead_id, :agent_name ], name: 'index_agent_outputs_on_lead_id_and_agent_name'
  end

  def down
    # Remove the non-unique index
    remove_index :agent_outputs, name: 'index_agent_outputs_on_lead_id_and_agent_name'

    # Re-add the unique constraint (this will fail if duplicates exist)
    add_index :agent_outputs, [ :lead_id, :agent_name ], unique: true, name: 'index_agent_outputs_on_lead_id_and_agent_name'
  end
end
