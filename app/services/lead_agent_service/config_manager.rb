##
# LeadAgentService::ConfigManager
#
# Manages agent configuration retrieval and default settings.
#
# This file is loaded via require_relative from lead_agent_service.rb
# and opens the existing LeadAgentService class to add the nested ConfigManager class.
#
class LeadAgentService::ConfigManager
  ##
  # Gets agent configuration for a campaign, creates default if not exists
  #
  # @param campaign [Campaign] The campaign
  # @param agent_name [String] The agent name
  # @return [AgentConfig] The agent configuration
  def self.get_agent_config(campaign, agent_name)
    # Reload association to ensure we have the latest configs (avoid stale cache)
    campaign.association(:agent_configs).reset if campaign.association(:agent_configs).loaded?
    
    # Try to find existing config - use find_by with explicit campaign_id to avoid any association issues
    config = AgentConfig.find_by(campaign_id: campaign.id, agent_name: agent_name)
    
    if config
      # Reload the config to ensure we have the latest enabled status
      config.reload
      Rails.logger.info("[ConfigManager] Found agent config for #{agent_name} (ID: #{config.id}, Campaign: #{config.campaign_id}): enabled=#{config.enabled.inspect} (class: #{config.enabled.class}), enabled?=#{config.enabled?}, disabled?=#{config.disabled?}")
      return config
    end
    
    # Create default config if it doesn't exist
    Rails.logger.info("[ConfigManager] Creating default agent config for #{agent_name} in campaign #{campaign.id}")
    campaign.agent_configs.create!(
      agent_name: agent_name,
      settings: default_settings_for_agent(agent_name),
      enabled: true  # Enabled by default to allow execution
    )
  end

  ##
  # Returns default settings for each agent type
  #
  # @param agent_name [String] The agent name
  # @return [Hash] Default settings hash
  def self.default_settings_for_agent(agent_name)
    case agent_name
    when AgentConstants::AGENT_WRITER
      { product_info: "", sender_company: "" }
    when AgentConstants::AGENT_SEARCH, AgentConstants::AGENT_DESIGN, AgentConstants::AGENT_CRITIQUE
      {}
    else
      {}
    end
  end
end
