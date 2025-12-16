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
    # Request/job-scoped cache to avoid duplicate queries for the same (campaign_id, agent_name) pair
    # Uses Current attributes which are automatically cleared at the end of each request/job
    # Current.config_cache is lazily initialized, so no nil check needed
    key = [ campaign.id, agent_name.to_s ]
    cache = Current.config_cache

    # Bound cache growth: if cache gets too large, skip caching for this lookup
    # (prevents memory issues with dynamic agent names or multitenancy)
    if cache.size > 500
      Rails.logger.warn("[ConfigManager] Cache size (#{cache.size}) exceeds limit, skipping cache for #{agent_name}")
      return uncached_lookup(campaign, agent_name)
    end

    # Check cache first
    return cache[key] if cache.key?(key)

    # Prefer preloaded association to avoid N+1
    config = nil
    if campaign.association(:agent_configs).loaded?
      config = campaign.agent_configs.find { |c| c.agent_name.to_s == agent_name.to_s }
    end

    # Fallback to DB query if not in preloaded association
    config ||= AgentConfig.find_by(campaign_id: campaign.id, agent_name: agent_name)

    if config
      Rails.logger.info("[ConfigManager] Found agent config for #{agent_name} (ID: #{config.id}, Campaign: #{config.campaign_id}): enabled=#{config.enabled.inspect} (class: #{config.enabled.class}), enabled?=#{config.enabled?}, disabled?=#{config.disabled?}")
    else
      # Create default config if it doesn't exist
      Rails.logger.info("[ConfigManager] Creating default agent config for #{agent_name} in campaign #{campaign.id}")
      config = campaign.agent_configs.create!(
        agent_name: agent_name,
        settings: default_settings_for_agent(agent_name),
        enabled: true  # Enabled by default to allow execution
      )
    end

    # Only cache actual configs (not nil) to avoid stale "not found" state
    # If config is created mid-request, subsequent lookups will find it
    Current.config_cache[key] = config if config

    config
  end

  private

  # Uncached lookup path (used when cache is too large or for direct calls)
  def self.uncached_lookup(campaign, agent_name)
    # Prefer preloaded association to avoid N+1
    config = nil
    if campaign.association(:agent_configs).loaded?
      config = campaign.agent_configs.find { |c| c.agent_name.to_s == agent_name.to_s }
    end

    # Fallback to DB query if not in preloaded association
    config ||= AgentConfig.find_by(campaign_id: campaign.id, agent_name: agent_name)

    if config
      Rails.logger.info("[ConfigManager] Found agent config for #{agent_name} (ID: #{config.id}, Campaign: #{config.campaign_id}): enabled=#{config.enabled.inspect}")
    else
      # Create default config if it doesn't exist
      Rails.logger.info("[ConfigManager] Creating default agent config for #{agent_name} in campaign #{campaign.id}")
      config = campaign.agent_configs.create!(
        agent_name: agent_name,
        settings: default_settings_for_agent(agent_name),
        enabled: true  # Enabled by default to allow execution
      )
    end

    config
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
