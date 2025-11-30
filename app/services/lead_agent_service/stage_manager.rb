##
# LeadAgentService::StageManager
#
# Manages lead stage progression and determines which agent should run next
# based on the current stage.
#
# This file is loaded via require_relative from lead_agent_service.rb
# and opens the existing LeadAgentService class to add the nested StageManager class.
#
class LeadAgentService::StageManager
  include AgentConstants

  ##
  # Determines which agent should run next based on current stage
  #
  # @param current_stage [String] The current stage of the lead
  # @return [String, nil] The next agent name or nil if at final stage
  def self.determine_next_agent(current_stage)
    stage_index = AgentConstants::STAGE_PROGRESSION.index(current_stage)
    return nil if stage_index.nil? || stage_index >= AgentConstants::STAGE_PROGRESSION.length - 1

    # Map stage to next agent
    # queued -> SEARCH (to become 'searched')
    # searched -> WRITER (to become 'written')
    # written -> CRITIQUE (to become 'critiqued')
    # critiqued -> DESIGN (to become 'designed')
    # designed -> nil (final stage)
    case current_stage
    when AgentConstants::STAGE_QUEUED
      AgentConstants::AGENT_SEARCH
    when AgentConstants::STAGE_SEARCHED
      AgentConstants::AGENT_WRITER
    when AgentConstants::STAGE_WRITTEN
      AgentConstants::AGENT_CRITIQUE
    when AgentConstants::STAGE_CRITIQUED
      AgentConstants::AGENT_DESIGN
    else
      nil
    end
  end

  ##
  # Advances lead to the next stage in the progression
  #
  # @param lead [Lead] The lead to advance
  # @param agent_name [String] The agent that just completed
  def self.advance_stage(lead, agent_name)
    current_index = AgentConstants::STAGE_PROGRESSION.index(lead.stage) || -1
    next_index = current_index + 1

    # Only advance if not already at the final stage
    if next_index < AgentConstants::STAGE_PROGRESSION.length
      new_stage = AgentConstants::STAGE_PROGRESSION[next_index]
      lead.update!(stage: new_stage)
    end
  end

  ##
  # Updates lead quality based on critique feedback
  #
  # @param lead [Lead] The lead to update
  # @param critique_output [Hash] The critique agent output
  def self.update_lead_quality(lead, critique_output)
    # Simple quality assessment based on critique presence
    # If critique is nil or empty, email was approved (high quality)
    # If critique exists, email needs improvement (medium quality)
    critique = critique_output.is_a?(Hash) ? critique_output["critique"] : nil
    quality = (critique.nil? || critique.empty?) ? "high" : "medium"

    if lead.quality != quality
      lead.update!(quality: quality)
    end
  end
end
