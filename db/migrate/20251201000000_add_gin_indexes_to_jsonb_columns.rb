##
# Migration: Add GIN Indexes to JSONB Columns
#
# Purpose: Add GIN (Generalized Inverted Index) indexes to JSONB columns to improve
# query performance when accessing nested values or filtering/searching within JSONB data.
#
# Why GIN Indexes:
# - GIN indexes are specifically designed for complex data types like JSONB
# - Enable fast searches within JSON documents using operators like @>, ?, ?&, ?|
# - Significantly improve performance when querying nested JSONB values
# - Essential for production scalability as data grows
#
# Indexes Added:
# 1. campaigns.shared_settings - Used for accessing brand_voice, primary_goal, product_info
# 2. agent_configs.settings - Used for accessing agent-specific configuration
# 3. agent_outputs.output_data - Used for accessing email content, variants, critique, etc.
#
class AddGinIndexesToJsonbColumns < ActiveRecord::Migration[8.1]
  def up
    # Add GIN index on campaigns.shared_settings
    # This speeds up queries that access nested values like shared_settings['brand_voice']
    add_index :campaigns, :shared_settings, using: :gin, name: 'index_campaigns_on_shared_settings_gin'

    # Add GIN index on agent_configs.settings
    # This speeds up queries that access agent configuration values
    add_index :agent_configs, :settings, using: :gin, name: 'index_agent_configs_on_settings_gin'

    # Add GIN index on agent_outputs.output_data
    # This speeds up queries that access email content, variants, and other output data
    add_index :agent_outputs, :output_data, using: :gin, name: 'index_agent_outputs_on_output_data_gin'
  end

  def down
    remove_index :campaigns, name: 'index_campaigns_on_shared_settings_gin'
    remove_index :agent_configs, name: 'index_agent_configs_on_settings_gin'
    remove_index :agent_outputs, name: 'index_agent_outputs_on_output_data_gin'
  end
end
