##
# LeadAgentService::OutputManager
#
# Manages agent output storage and retrieval from the database.
#
# This file is loaded via require_relative from lead_agent_service.rb
# and opens the existing LeadAgentService class to add the nested OutputManager class.
#
class LeadAgentService::OutputManager
  include AgentConstants

  ##
  # Loads previous agent outputs that are needed for the current agent
  # Always returns the LATEST output (most recent created_at) for each agent
  #
  # @param lead [Lead] The lead containing agent outputs
  # @param current_agent [String] The agent that needs previous outputs
  # @return [Hash] Hash of previous outputs keyed by agent name
  def self.load_previous_outputs(lead, current_agent)
    outputs = {}

    # Helper method to get latest completed output for an agent
    latest_output = lambda do |agent_name|
      lead.agent_outputs
          .where(agent_name: agent_name, status: AgentConstants::STATUS_COMPLETED)
          .order(created_at: :desc)
          .first
    end

    # WRITER needs SEARCH output - get the latest completed one
    if current_agent == AgentConstants::AGENT_WRITER
      search_output = latest_output.call(AgentConstants::AGENT_SEARCH)
      outputs[AgentConstants::AGENT_SEARCH] = search_output&.output_data || {}
      Rails.logger.info("[OutputManager] Loading SEARCH output for WRITER: ID=#{search_output.id if search_output}")
    end

    if current_agent == AgentConstants::AGENT_CRITIQUE
      # Get the LATEST WRITER output (most recent revision) - only completed outputs
      writer_output = latest_output.call(AgentConstants::AGENT_WRITER)
      if writer_output
        Rails.logger.info("[OutputManager] Loading WRITER output for CRITIQUE: ID=#{writer_output.id}, created_at=#{writer_output.created_at}")
      else
        Rails.logger.warn("[OutputManager] No completed WRITER output found for CRITIQUE agent")
      end
      outputs[AgentConstants::AGENT_WRITER] = writer_output&.output_data || {}
    end

    if current_agent == AgentConstants::AGENT_DESIGN
      # DESIGN needs CRITIQUE output, and might also need WRITER/SEARCH for fallback
      critique_output = latest_output.call(AgentConstants::AGENT_CRITIQUE)
      outputs[AgentConstants::AGENT_CRITIQUE] = critique_output&.output_data || {}
      Rails.logger.info("[OutputManager] Loading CRITIQUE output for DESIGN: ID=#{critique_output.id if critique_output}")

      # Also load WRITER output for fallback (design agent may use it if critique output is empty)
      writer_output = latest_output.call(AgentConstants::AGENT_WRITER)
      outputs[AgentConstants::AGENT_WRITER] = (writer_output&.output_data || {}) if writer_output
    end

    outputs
  end

  ##
  # Saves agent output to the database
  # Creates a NEW record each time (allows multiple versions/history)
  #
  # @param lead [Lead] The lead to save output for
  # @param agent_name [String] The agent name
  # @param output_data [Hash] The output data to save
  # @param status [String] The status (completed, failed, pending)
  def self.save_agent_output(lead, agent_name, output_data, status)
    # Sanitize output data to remove null bytes that PostgreSQL can't handle
    sanitized_output = sanitize_for_postgres(output_data)

    # Always create a NEW record - never update existing ones
    agent_output = lead.agent_outputs.build(
      agent_name: agent_name,
      output_data: sanitized_output,
      status: status,
      error_message: status == AgentConstants::STATUS_FAILED ? sanitized_output[:error] || sanitized_output["error"] : nil
    )
    agent_output.save!
    Rails.logger.info("[OutputManager] Created new #{agent_name} output: ID=#{agent_output.id}, created_at=#{agent_output.created_at}")
    agent_output
  end

  ##
  # Recursively sanitizes data to remove null bytes (\u0000) that PostgreSQL can't store
  # Also removes other problematic Unicode characters
  #
  # @param data [Object] The data to sanitize (Hash, Array, String, or other)
  # @return [Object] Sanitized data
  def self.sanitize_for_postgres(data)
    case data
    when Hash
      data.transform_values { |v| sanitize_for_postgres(v) }
    when Array
      data.map { |v| sanitize_for_postgres(v) }
    when String
      # Remove null bytes and other problematic characters
      data.gsub("\u0000", "").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    else
      data
    end
  end

  ##
  # Creates error output with agent-specific fields
  #
  # @param error [Exception] The error that occurred
  # @param agent_name [String] The agent that failed
  # @param lead [Lead] The lead being processed
  # @return [Hash] Error output hash
  def self.create_error_output(error, agent_name, lead)
    error_output = { error: error.message, agent: agent_name }

    # Add agent-specific fields for error outputs
    case agent_name
    when AgentConstants::AGENT_WRITER
      error_output[:email] = ""
      error_output[:company] = lead.company
      error_output[:recipient] = lead.name
    when AgentConstants::AGENT_DESIGN
      error_output[:email] = ""
      error_output[:formatted_email] = ""
      error_output[:company] = lead.company
      error_output[:recipient] = lead.name
    when AgentConstants::AGENT_CRITIQUE
      error_output["critique"] = nil
    end

    error_output
  end
end
