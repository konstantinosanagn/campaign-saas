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
    campaign.agent_configs.find_by(agent_name: agent_name) ||
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
