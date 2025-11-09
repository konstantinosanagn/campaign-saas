class UpdateAgentNameConstraintsToIncludeDesign < ActiveRecord::Migration[8.1]
  def up
    # Drop existing constraints
    execute <<-SQL
      ALTER TABLE agent_configs
      DROP CONSTRAINT IF EXISTS check_agent_configs_agent_name;
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      DROP CONSTRAINT IF EXISTS check_agent_outputs_agent_name;
    SQL

    # Recreate constraints with DESIGN included
    execute <<-SQL
      ALTER TABLE agent_configs
      ADD CONSTRAINT check_agent_configs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'DESIGN', 'CRITIQUE', 'DESIGNER', 'SENDER'));
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      ADD CONSTRAINT check_agent_outputs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'DESIGN', 'CRITIQUE', 'DESIGNER', 'SENDER'));
    SQL
  end

  def down
    # Drop constraints
    execute <<-SQL
      ALTER TABLE agent_configs
      DROP CONSTRAINT IF EXISTS check_agent_configs_agent_name;
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      DROP CONSTRAINT IF EXISTS check_agent_outputs_agent_name;
    SQL

    # Recreate original constraints (without DESIGN)
    execute <<-SQL
      ALTER TABLE agent_configs
      ADD CONSTRAINT check_agent_configs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'CRITIQUE', 'DESIGNER', 'SENDER'));
    SQL

    execute <<-SQL
      ALTER TABLE agent_outputs
      ADD CONSTRAINT check_agent_outputs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'CRITIQUE', 'DESIGNER', 'SENDER'));
    SQL
  end
end
