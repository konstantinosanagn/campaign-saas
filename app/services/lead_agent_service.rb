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
  require_relative "lead_agent_service/stage_manager"
  require_relative "lead_agent_service/output_manager"
  require_relative "lead_agent_service/executor"
  require_relative "lead_agent_service/config_manager"

  # Stage progression: queued → searched → written → critiqued → designed → completed
  # Each agent moves the lead to the next stage in the progression

  class << self
    ##
    # Runs the NEXT agent for a specific lead based on its current stage
    # Only runs ONE agent at a time to allow for human review between stages
    # @param lead [Lead] The lead to process
    # @param campaign [Campaign] The campaign containing agent configs
    # @param user [User] Current user containing API keys
    # @return [Hash] Result with status, outputs, and updated lead
    def run_agents_for_lead(lead, campaign, user)
      # Validate API keys before starting
      unless ApiKeyService.keys_available?(user)
        missing_keys = ApiKeyService.missing_keys(user)
        return {
          status: "failed",
          error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section.",
          outputs: {},
          lead: lead
        }
      end

      # Check if lead is already at final stage
      next_agent = LeadAgentService::StageManager.determine_next_agent(lead.stage)
      unless next_agent
        # Lead is already at final stage
        return {
          status: "completed",
          error: "Lead has already reached the final stage",
          outputs: {},
          lead: lead,
          completed_agents: [],
          failed_agents: []
        }
      end

      # Get API keys
      gemini_key = ApiKeyService.get_gemini_api_key(user)
      tavily_key = ApiKeyService.get_tavily_api_key(user)

      # Initialize agents
      search_agent = Agents::SearchAgent.new(tavily_key: tavily_key, gemini_key: gemini_key)
      writer_agent = Agents::WriterAgent.new(api_key: gemini_key)
      critique_agent = Agents::CritiqueAgent.new(api_key: gemini_key)
      design_agent = Agents::DesignAgent.new(api_key: gemini_key)

      # Track execution results
      outputs = {}
      completed_agents = []
      failed_agents = []

      # Run agents, skipping disabled ones and continuing to the next enabled agent
      # Stop after the first successful execution (or failure)
      max_iterations = 10 # Safety limit to prevent infinite loops
      iteration = 0
      agent_executed = false

      while iteration < max_iterations && !agent_executed
        iteration += 1

        # Determine which agent to run based on current stage
        next_agent = LeadAgentService::StageManager.determine_next_agent(lead.stage)

        # If already at final stage, break
        unless next_agent
          break
        end

        # Get agent config for this campaign
        agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, next_agent)

        # Skip if agent is disabled - advance stage and continue to next agent
        if agent_config&.disabled?
          # Still advance stage for disabled agents
          LeadAgentService::StageManager.advance_stage(lead, next_agent)
          lead.reload
          # Continue to next agent without executing
          next
        end

        # Execute the agent (this is the first enabled agent we found)
        begin
          # Load previous outputs if needed
          previous_outputs = LeadAgentService::OutputManager.load_previous_outputs(lead, next_agent)

          # Prepare agents hash for executor
          agents = {
            search: search_agent,
            writer: writer_agent,
            critique: critique_agent,
            design: design_agent
          }

          # Execute agent based on type
          result = LeadAgentService::Executor.execute_agent(next_agent, agents, lead, agent_config, previous_outputs)

          # Store output
          LeadAgentService::OutputManager.save_agent_output(lead, next_agent, result, AgentConstants::STATUS_COMPLETED)
          outputs[next_agent] = result
          completed_agents << next_agent

          # Advance to next stage
          LeadAgentService::StageManager.advance_stage(lead, next_agent)

          # Update lead quality if CRITIQUE completed successfully
          if next_agent == AgentConstants::AGENT_CRITIQUE && result
            LeadAgentService::StageManager.update_lead_quality(lead, result)
          end

          # Mark that we've executed an agent and break
          agent_executed = true
          lead.reload

        rescue => e
          # Store error output with appropriate fields based on agent type
          error_output = LeadAgentService::OutputManager.create_error_output(e, next_agent, lead)

          LeadAgentService::OutputManager.save_agent_output(lead, next_agent, error_output, AgentConstants::STATUS_FAILED)
          outputs[next_agent] = error_output
          failed_agents << next_agent

          # DO NOT advance stage if agent failed
          # Lead stays at current stage for retry
          # Mark as executed and break
          agent_executed = true
        end
      end

      # Determine overall status
      status = determine_status(completed_agents, failed_agents)

      # Reload lead to get updated attributes
      lead.reload

      {
        status: status,
        outputs: outputs,
        lead: lead,
        completed_agents: completed_agents,
        failed_agents: failed_agents
      }
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
