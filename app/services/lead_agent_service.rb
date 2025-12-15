require_relative "api_key_service"
require_relative "agents/search_agent"
require_relative "agents/writer_agent"
require_relative "agents/critique_agent"
require_relative "agents/design_agent"

##
# LeadAgentService
#
# Orchestrates the execution of agents (SEARCH → WRITER → CRITIQUE → DESIGN) for a specific lead.
# Manages agent configuration retrieval, sequential execution, output storage, and stage updates.
#
# Usage:
#   result = LeadAgentService.run_agents_for_lead(lead, campaign, user)
#   # Returns: { status: 'completed'|'partial'|'failed', outputs: {...}, lead: {...} }
#
class LeadAgentService
  include AgentConstants

  # Load nested classes after the main class is defined
  require_relative "lead_agent_service/output_manager"
  require_relative "lead_agent_service/executor"
  require_relative "lead_agent_service/config_manager"

  # Stage progression: queued → searched → written → critiqued → designed → completed
  # Each agent moves the lead to the next stage in the progression

  class << self
    ##
    # Runs an agent for a specific lead
    # If agent_name is provided, runs that specific agent
    # Otherwise, runs the NEXT agent based on current stage
    # Only runs ONE agent at a time to allow for human review between stages
    # @param lead [Lead] The lead to process
    # @param campaign [Campaign] The campaign containing agent configs
    # @param user [User] Current user containing API keys
    # @param agent_name [String, nil] Optional specific agent to run (SEARCH, WRITER, CRITIQUE, DESIGN)
    # @return [Hash] Result with status, outputs, and updated lead
    def run_agents_for_lead(lead, campaign, user, agent_name: nil)
      raise NotImplementedError, "LeadAgentService legacy pipeline has been removed; use LeadRuns (LeadRunPlanner/LeadRunExecutor/AgentExecutionJob)."
    end

    private

    ##
    # Determines overall execution status
    def determine_status(completed_agents, failed_agents)
      if failed_agents.any?
        "failed"
      elsif completed_agents.any?
        "completed"  # Single agent completion is still 'completed'
      else
        "failed"
      end
    end
  end
end
