# Migration: CreateAgentConfigs
#
# Purpose: Store per-campaign agent settings/configuration for SEARCH, WRITER, CRITIQUE agents
#
# Key Design Decisions:
# - Uses JSONB for settings to allow flexible agent-specific configuration structures
#   - WRITER: {product_info: string, sender_company: string}
#   - SEARCH: {} (currently no settings, but structure ready for future)
#   - CRITIQUE: {} (currently no settings, but structure ready for future)
# - Unique constraint on [campaign_id, agent_name] ensures one config per agent per campaign
#   (allows each campaign to customize agent behavior independently)
# - Index on campaign_id enables fast lookups of all configs for a campaign
# - Index on agent_name enables queries like "all WRITER configs" across campaigns
# - enabled boolean allows temporarily disabling an agent for a campaign
# - Check constraints enforce valid agent_name at database level
#
# Future Considerations:
# - As agents gain more settings, JSONB allows flexible expansion without migrations
# - If settings become very complex, consider extracting to separate tables
# - GIN indexes on JSONB fields may improve query performance if we query within settings
#
class CreateAgentConfigs < ActiveRecord::Migration[8.1]
  def up
    create_table :agent_configs do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :agent_name, null: false, limit: 50
      t.jsonb :settings, null: false, default: {}
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    # Unique constraint: one config per agent per campaign
    # Note: campaign_id index already created by t.references above
    add_index :agent_configs, [ :campaign_id, :agent_name ], unique: true, name: 'index_agent_configs_on_campaign_id_and_agent_name'

    # Performance index for agent_name queries
    add_index :agent_configs, :agent_name

    # Database-level check constraints for data integrity
    execute <<-SQL
      ALTER TABLE agent_configs
      ADD CONSTRAINT check_agent_configs_agent_name
      CHECK (agent_name IN ('SEARCH', 'WRITER', 'CRITIQUE'));
    SQL

    execute <<-SQL
      ALTER TABLE agent_configs
      ADD CONSTRAINT check_agent_configs_enabled
      CHECK (enabled IN (true, false));
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE agent_configs
      DROP CONSTRAINT IF EXISTS check_agent_configs_agent_name;
    SQL

    execute <<-SQL
      ALTER TABLE agent_configs
      DROP CONSTRAINT IF EXISTS check_agent_configs_enabled;
    SQL

    drop_table :agent_configs
  end
end
