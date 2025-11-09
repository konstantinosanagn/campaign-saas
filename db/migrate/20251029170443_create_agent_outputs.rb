# Migration: CreateAgentOutputs
#
# Purpose: Store outputs from agent executions (SEARCH, WRITER, CRITIQUE) for each lead
#
# Key Design Decisions:
# - Uses JSONB for output_data to store flexible agent-specific output structures
# - Unique constraint on [lead_id, agent_name] ensures one output per agent per lead
#   (prevents duplicates if agent is run multiple times - last run wins via update)
# - Index on lead_id enables fast lookups of all outputs for a lead
# - Index on agent_name enables queries like "all SEARCH outputs" across leads
# - Check constraints enforce valid agent_name and status at database level
# - Status field tracks: 'pending' (running), 'completed' (success), 'failed' (error)
# - error_message stores agent execution errors for debugging
#
# Future Considerations:
# - If we need to track history of multiple runs, consider adding a version/timestamp
# - JSONB allows querying within output_data but we may want GIN indexes later
#
class CreateAgentOutputs < ActiveRecord::Migration[8.1]
  def up
    create_table :agent_outputs do |t|
      t.references :lead, null: false, foreign_key: true
      t.string :agent_name, null: false, limit: 50
      t.jsonb :output_data, null: false, default: {}
      t.string :status, null: false, default: 'pending', limit: 20
      t.text :error_message

      t.timestamps
    end

    # Unique constraint: one output per agent per lead
    # Note: lead_id index already created by t.references above
    add_index :agent_outputs, [ :lead_id, :agent_name ], unique: true, name: 'index_agent_outputs_on_lead_id_and_agent_name'

    # Performance index for agent_name queries
    add_index :agent_outputs, :agent_name

    # Database-level check constraints for data integrity
    execute <<-SQL
      ALTER TABLE agent_outputs
      ADD CONSTRAINT check_agent_outputs_status
      CHECK (status IN ('pending', 'completed', 'failed'));
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      ADD CONSTRAINT check_agent_outputs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'CRITIQUE'));
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE agent_outputs
      DROP CONSTRAINT IF EXISTS check_agent_outputs_status;
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      DROP CONSTRAINT IF EXISTS check_agent_outputs_agent_name;
    SQL

    drop_table :agent_outputs
  end
end
