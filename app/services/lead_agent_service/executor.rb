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

  ##
  # Executes the SearchAgent
  #
  # @param search_agent [Agents::SearchAgent] The search agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @return [Hash] Search results
  def self.execute_search_agent(search_agent, lead, agent_config)
    search_agent.run(
      company: lead.company,
      recipient_name: lead.name,
      job_title: lead.title || "",
      email: lead.email,
      tone: agent_config&.settings&.dig("tone"),
      persona: agent_config&.settings&.dig("sender_persona"),
      goal: (lead.campaign.shared_settings || {})["primary_goal"]
    )
  end

  ##
  # Executes the WriterAgent
  #
  # @param writer_agent [Agents::WriterAgent] The writer agent instance
  # @param lead [Lead] The lead to process
  # @param agent_config [AgentConfig] The agent configuration
  # @param search_output [Hash] The search agent output
  # @return [Hash] Writer results
  def self.execute_writer_agent(writer_agent, lead, agent_config, search_output)
    return writer_agent.run({ company: lead.company, sources: [] }, recipient: lead.name, company: lead.company) unless search_output

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

    settings        = agent_config&.settings || {}
    shared_settings = lead.campaign.shared_settings || {}

    product_info   = shared_settings["product_info"]   || settings["product_info"]
    sender_company = shared_settings["sender_company"] || settings["sender_company"]

    writer_agent.run(
      search_results,
      recipient: lead.name,
      company: lead.company,
      product_info: product_info,
      sender_company: sender_company,
      config: { settings: settings },
      shared_settings: shared_settings
    )
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
    # Prepare writer output for critique
    # Handle both string and symbol keys from JSONB storage
    email_content = writer_output&.dig("email") ||
                    writer_output&.dig(:email) ||
                    writer_output&.dig("formatted_email") ||
                    writer_output&.dig(:formatted_email) ||
                    ""

    # Get variants if they exist
    variants = writer_output&.dig("variants") || writer_output&.dig(:variants) || []

    article = {
      "email_content" => email_content,
      "variants" => variants,
      "number_of_revisions" => 0
    }

    # Pass config to critique_agent
    config_hash = agent_config ? { settings: agent_config.settings } : nil
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
    # Prepare critique output for design
    # Prefer selected_variant if available, otherwise use email_content or email
    # Handle both string and symbol keys from JSONB storage
    email_content = critique_output&.dig("selected_variant") ||
                    critique_output&.dig(:selected_variant) ||
                    critique_output&.dig("email_content") ||
                    critique_output&.dig(:email_content) ||
                    critique_output&.dig("email") ||
                    critique_output&.dig(:email) ||
                    ""

    # Fallback to WRITER output if critique_output doesn't have email
    if email_content.blank?
      writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)
      if writer_output
        email_content = writer_output.output_data["email"] ||
                       writer_output.output_data[:email] ||
                       writer_output.output_data["formatted_email"] ||
                       writer_output.output_data[:formatted_email] ||
                       ""
      end
    end

    # Get company and recipient from lead
    company = lead.company
    recipient = lead.name

    # Prepare input hash for design agent
    design_input = {
      email: email_content,
      company: company,
      recipient: recipient
    }

    # Pass config to design_agent
    config_hash = agent_config ? { settings: agent_config.settings } : nil
    design_agent.run(design_input, config: config_hash)
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
