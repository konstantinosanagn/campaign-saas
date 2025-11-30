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
  #
  # @param lead [Lead] The lead containing agent outputs
  # @param current_agent [String] The agent that needs previous outputs
  # @return [Hash] Hash of previous outputs keyed by agent name
  def self.load_previous_outputs(lead, current_agent)
    outputs = {}

    # WRITER needs SEARCH output
    if current_agent == AgentConstants::AGENT_WRITER
      search_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_SEARCH)
      outputs[AgentConstants::AGENT_SEARCH] = search_output&.output_data
    end

    if current_agent == AgentConstants::AGENT_CRITIQUE
      writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)
      outputs[AgentConstants::AGENT_WRITER] = writer_output&.output_data
    end

    if current_agent == AgentConstants::AGENT_DESIGN
      critique_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_CRITIQUE)
      outputs[AgentConstants::AGENT_CRITIQUE] = critique_output&.output_data
    end

    outputs
  end

  ##
  # Saves agent output to the database
  #
  # @param lead [Lead] The lead to save output for
  # @param agent_name [String] The agent name
  # @param output_data [Hash] The output data to save
  # @param status [String] The status (completed, failed, pending)
  def self.save_agent_output(lead, agent_name, output_data, status)
    agent_output = lead.agent_outputs.find_or_initialize_by(agent_name: agent_name)
    agent_output.assign_attributes(
      output_data: output_data,
      status: status,
      error_message: status == AgentConstants::STATUS_FAILED ? output_data[:error] : nil
    )
    agent_output.save!
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
