##
# LeadAgentService::Executor
#
# Handles the execution of individual agents with proper input preparation
# and error handling.
#
# This file is loaded via require_relative from lead_agent_service.rb
# and opens the existing LeadAgentService class to add the nested Executor class.
#
require_relative "../agents/search_agent"
require_relative "../agents/writer_agent"
require_relative "../agents/critique_agent"
require_relative "../agents/design_agent"

class LeadAgentService::Executor
  include AgentConstants
  extend SettingsHelper  # Use extend for class methods

  ##
  # Replaces placeholders in email text with actual user name
  #
  # @param text [String] The email text that may contain placeholders
  # @param sender_name [String] The actual sender's name to use
  # @return [String] Text with placeholders replaced
  def self.replace_placeholders(text, sender_name)
    return text if sender_name.blank? || text.blank?

    # Escape sender_name for use in regex (handle special characters)
    escaped_name = Regexp.escape(sender_name)

    # Replace common placeholder patterns (case-insensitive)
    # Patterns: [Your Name], [Sender Name], [Name], etc.
    text = text.gsub(/\[(?:Your|YOUR|your)\s+(?:Name|NAME|name)\]/i, sender_name)
    text = text.gsub(/\[(?:Sender|SENDER|sender)\s+(?:Name|NAME|name)\]/i, sender_name)
    text = text.gsub(/\[(?:Name|NAME|name)\]/i, sender_name)

    text
  end

  ##
  # Executes the SearchAgent
  #
  # @param search_agent [Agents::SearchAgent] The search agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @return [Hash] Search results
  def self.execute_search_agent(search_agent, lead, agent_config)
    # Reload agent_config to ensure we have the latest settings (avoid stale cache)
    agent_config.reload if agent_config

    # Get settings after reload to ensure fresh data
    settings = agent_config&.settings || {}

    # Log for debugging
    Rails.logger.info("SearchAgent Executor - Agent Config ID: #{agent_config&.id}, settings: #{settings.inspect}")

    search_agent.run(
      company: lead.company,
      recipient_name: lead.name,
      job_title: lead.title || "",
      email: lead.email,
      tone: SettingsHelper.get_setting(settings, :tone) || SettingsHelper.get_setting(settings, "tone"),
      persona: SettingsHelper.get_setting(settings, :sender_persona) || SettingsHelper.get_setting(settings, "sender_persona"),
      goal: SettingsHelper.get_setting(lead.campaign.shared_settings || {}, :primary_goal) || SettingsHelper.get_setting(lead.campaign.shared_settings || {}, "primary_goal"),
      config: { settings: settings }
    )
  end

  ##
  # Executes the WriterAgent
  #
  # @param writer_agent [Agents::WriterAgent] The writer agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @param search_output [Hash] The search agent output
  # @param previous_critique [String, nil] Optional critique feedback from previous critique run
  # @return [Hash] Writer results
  def self.execute_writer_agent(writer_agent, lead, agent_config, search_output, previous_critique: nil)
    # Reload agent_config to ensure we have the latest settings (avoid stale cache)
    agent_config.reload if agent_config

    # Reload campaign association to ensure we have latest shared_settings
    lead.association(:campaign).reload if lead.association(:campaign).loaded?
    campaign = lead.campaign
    # Use read_attribute to get raw DB value, not the getter with defaults
    raw_shared_settings = campaign.read_attribute(:shared_settings) || {}
    shared_settings = raw_shared_settings.is_a?(Hash) && !raw_shared_settings.empty? ? raw_shared_settings : {}

    # Get settings after reload to ensure fresh data
    settings = agent_config&.settings || {}

    # Log for debugging
    Rails.logger.info("WriterAgent Executor - Campaign ID: #{campaign.id}")
    Rails.logger.info("WriterAgent Executor - Agent Config ID: #{agent_config&.id}")
    Rails.logger.info("WriterAgent Executor - Raw shared_settings from DB: #{raw_shared_settings.inspect}")
    Rails.logger.info("WriterAgent Executor - Final shared_settings: #{shared_settings.inspect}")
    Rails.logger.info("WriterAgent Executor - primary_goal value: #{SettingsHelper.get_setting(shared_settings, :primary_goal) || SettingsHelper.get_setting(shared_settings, 'primary_goal')}")
    Rails.logger.info("WriterAgent Executor - agent_config settings (after reload): #{settings.inspect}")

    product_info   = SettingsHelper.get_setting(shared_settings, :product_info) || SettingsHelper.get_setting(shared_settings, "product_info") || SettingsHelper.get_setting(settings, :product_info)
    sender_company = SettingsHelper.get_setting(shared_settings, :sender_company) || SettingsHelper.get_setting(shared_settings, "sender_company") || SettingsHelper.get_setting(settings, :sender_company)

    # If no search_output, return early but WITH config and shared_settings
    unless search_output
      Rails.logger.info("WriterAgent Executor - No search_output available, using empty sources but WITH config")
      # Get user's name for placeholder replacement
      user = campaign.user
      sender_name = user&.name || user&.first_name || ""

      result = writer_agent.run(
        { company: lead.company, sources: [] },
        recipient: lead.name,
        company: lead.company,
        product_info: product_info,
        sender_company: sender_company,
        config: { settings: settings },
        shared_settings: shared_settings,
        previous_critique: previous_critique,
        sender_name: sender_name
      )

      # Replace placeholders in generated email with actual user name
      if sender_name.present? && result.is_a?(Hash)
        result = result.deep_dup
        if result[:email].present?
          result[:email] = replace_placeholders(result[:email], sender_name)
        end
        if result[:variants].is_a?(Array)
          result[:variants] = result[:variants].map { |variant| replace_placeholders(variant, sender_name) }
        end
      end

      result
    end

    search_output = search_output.deep_symbolize_keys
    # Extract unified sources (recipient + company)
    recipient_sources = Array(search_output.dig(:personalization_signals, :recipient))
    company_sources   = Array(search_output.dig(:personalization_signals, :company))
    combined_sources  = (recipient_sources + company_sources).uniq

    search_results = {
      company: lead.company,
      sources: combined_sources,
      inferred_focus_areas: search_output[:inferred_focus_areas]
    }

    # Get user's name for placeholder replacement
    user = campaign.user
    sender_name = user&.name || user&.first_name || ""

    result = writer_agent.run(
      search_results,
      recipient: lead.name,
      company: lead.company,
      product_info: product_info,
      sender_company: sender_company,
      config: { settings: settings },
      shared_settings: shared_settings,
      previous_critique: previous_critique,
      sender_name: sender_name
    )

    # Replace placeholders in generated email with actual user name
    if sender_name.present? && result.is_a?(Hash)
      result = result.deep_dup
      if result[:email].present?
        result[:email] = replace_placeholders(result[:email], sender_name)
      end
      if result[:variants].is_a?(Array)
        result[:variants] = result[:variants].map { |variant| replace_placeholders(variant, sender_name) }
      end
    end

    result
  end

  ##
  # Executes the CritiqueAgent
  #
  # @param critique_agent [Agents::CritiqueAgent] The critique agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @param writer_output [Hash] The writer agent output
  # @return [Hash] Critique results
  def self.execute_critique_agent(critique_agent, lead, agent_config, writer_output)
    # Reload agent_config to ensure we have the latest settings (avoid stale cache)
    agent_config.reload if agent_config
    # Prepare writer output for critique
    # Handle both string and symbol keys from JSONB storage
    email_content = SettingsHelper.get_setting(writer_output, :email) || SettingsHelper.get_setting(writer_output, "email") ||
                    SettingsHelper.get_setting(writer_output, :formatted_email) || SettingsHelper.get_setting(writer_output, "formatted_email") || ""

    # Get variants if they exist
    variants = SettingsHelper.get_setting(writer_output, :variants) || SettingsHelper.get_setting(writer_output, "variants") || []

    article = {
      "email_content" => email_content,
      "variants" => variants,
      "number_of_revisions" => 0
    }

    # Pass config to critique_agent (use reloaded settings)
    config_hash = agent_config ? { settings: agent_config.settings } : nil
    Rails.logger.info("CritiqueAgent Executor - Agent Config ID: #{agent_config&.id}, settings: #{config_hash&.dig(:settings)&.inspect}")

    # Log email content snippet for debugging - helps verify we're critiquing the latest version
    Rails.logger.info(
      "[CritiqueAgent Executor] Critiquing email for lead_id=#{lead.id}, " \
      "email snippet=#{email_content.to_s[0..80].inspect}"
    )

    result = critique_agent.run(article, config: config_hash)

    # If a variant was selected, update the email content
    if result["selected_variant"]
      result["email"] = result["selected_variant"]
      result["email_content"] = result["selected_variant"]
    end

    result
  end

  ##
  # Executes the DesignAgent
  #
  # @param design_agent [Agents::DesignAgent] The design agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @param critique_output [Hash] The critique agent output
  # @return [Hash] Design results
  def self.execute_design_agent(design_agent, lead, agent_config, critique_output)
    # Reload agent_config to ensure we have the latest settings (avoid stale cache)
    agent_config.reload if agent_config
    # Prepare critique output for design
    # Prefer selected_variant if available, otherwise use email_content or email
    # Handle both string and symbol keys from JSONB storage
    email_content = SettingsHelper.get_setting(critique_output, :selected_variant) || SettingsHelper.get_setting(critique_output, "selected_variant") ||
                    SettingsHelper.get_setting(critique_output, :email_content) || SettingsHelper.get_setting(critique_output, "email_content") ||
                    SettingsHelper.get_setting(critique_output, :email) || SettingsHelper.get_setting(critique_output, "email") || ""

    # Fallback to WRITER output if critique_output doesn't have email
    # Get the LATEST writer output
    if email_content.blank?
      writer_output = lead.agent_outputs
                          .where(agent_name: AgentConstants::AGENT_WRITER)
                          .order(created_at: :desc)
                          .first
      if writer_output
        email_content = SettingsHelper.get_setting(writer_output.output_data, :email) || SettingsHelper.get_setting(writer_output.output_data, "email") ||
                       SettingsHelper.get_setting(writer_output.output_data, :formatted_email) || SettingsHelper.get_setting(writer_output.output_data, "formatted_email") || ""
      end
    end

    # Get company and recipient from lead
    company = lead.company
    recipient = lead.name

    # Get user's name for placeholder replacement
    campaign = lead.campaign
    user = campaign.user
    sender_name = user&.name || user&.first_name || ""

    # Replace placeholders in email content before passing to DesignAgent
    if sender_name.present? && email_content.present?
      email_content = replace_placeholders(email_content, sender_name)
    end

    # Prepare input hash for design agent
    design_input = {
      email: email_content,
      company: company,
      recipient: recipient
    }

    # Pass config to design_agent (use reloaded settings)
    config_hash = agent_config ? { settings: agent_config.settings } : nil
    Rails.logger.info("DesignAgent Executor - Agent Config ID: #{agent_config&.id}, settings: #{config_hash&.dig(:settings)&.inspect}")
    result = design_agent.run(design_input, config: config_hash)

    # Also replace placeholders in DesignAgent output as a safeguard
    if sender_name.present? && result.is_a?(Hash)
      result = result.deep_dup
      if result[:email].present?
        result[:email] = replace_placeholders(result[:email], sender_name)
      end
      if result[:formatted_email].present?
        result[:formatted_email] = replace_placeholders(result[:formatted_email], sender_name)
      end
    end

    result
  end

  ##
  # Executes an agent based on its type
  #
  # @param agent_name [String] The agent name
  # @param agents [Hash] Hash of agent instances
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @param previous_outputs [Hash] Previous agent outputs
  # @return [Hash] Agent execution result
  def self.execute_agent(agent_name, agents, lead, agent_config, previous_outputs)
    case agent_name
    when AgentConstants::AGENT_SEARCH
      execute_search_agent(agents[:search], lead, agent_config)
    when AgentConstants::AGENT_WRITER
      execute_writer_agent(agents[:writer], lead, agent_config, previous_outputs[AgentConstants::AGENT_SEARCH])
    when AgentConstants::AGENT_CRITIQUE
      execute_critique_agent(agents[:critique], lead, agent_config, previous_outputs[AgentConstants::AGENT_WRITER])
    when AgentConstants::AGENT_DESIGN
      execute_design_agent(agents[:design], lead, agent_config, previous_outputs[AgentConstants::AGENT_CRITIQUE])
    else
      raise ArgumentError, "Unknown agent: #{agent_name}"
    end
  end
end
