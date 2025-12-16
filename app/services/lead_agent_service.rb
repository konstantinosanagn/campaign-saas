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
      # Reload lead to ensure we have the latest data, especially after deletions/recreations
      # This prevents using stale data from cached associations
      lead.reload
      # Clear agent_outputs association cache to ensure fresh queries
      lead.association(:agent_outputs).reset

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

      # Determine which agent to run
      # If agent_name is provided, use it (manual execution)
      # Otherwise, determine from stage (automatic)
      if agent_name.present?
        next_agent = agent_name
        skip_stage = nil
        Rails.logger.info("[LeadAgentService] Running specific agent: #{next_agent}")
      else
        agent_info = LeadAgentService::StageManager.determine_next_agent(lead.stage, campaign: campaign)
        unless agent_info
          # Check if we're at final stage
          if lead.stage == AgentConstants::STAGE_DESIGNED || lead.stage == AgentConstants::STAGE_COMPLETED
            return {
              status: "completed",
              error: "Lead has already reached the final stage",
              outputs: {},
              lead: lead,
              completed_agents: [],
              failed_agents: []
            }
          else
            # All remaining agents are disabled
            return {
              status: "blocked",
              error: "All remaining agents in sequence are disabled. Lead cannot progress from stage '#{lead.stage}'.",
              outputs: {},
              lead: lead,
              completed_agents: [],
              failed_agents: []
            }
          end
        end

        next_agent = agent_info[:agent]
        skip_stage = agent_info[:skip_stage]

        # If we need to skip disabled agents, advance the stage first
        if skip_stage
          Rails.logger.info("[LeadAgentService] Skipping disabled agents, advancing lead #{lead.id} from #{lead.stage} to #{skip_stage}")
          lead.update!(stage: skip_stage)
          lead.reload
        end

        Rails.logger.info("[LeadAgentService] Determined next agent from stage: #{next_agent}")
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

      # Track if this is a manual execution (user explicitly requested an agent)
      is_manual_execution = agent_name.present?

      # Safety guard against infinite loops
      max_iterations = 10
      iteration = 0

      # Loop to keep walking pipeline when agents are disabled (only when agent_name is nil)
      # But with a safety limit to prevent infinite loops
      loop do
        iteration += 1
        if iteration > max_iterations
          Rails.logger.error("[LeadAgentService] Runaway loop detected for lead #{lead.id} at stage #{lead.stage} after #{iteration} iterations")
          raise "LeadAgentService runaway loop detected for lead #{lead.id} at stage #{lead.stage}"
        end

        # Reload lead to get latest stage
        lead.reload
        lead.association(:agent_outputs).reset

        # Determine next agent (only if agent_name was nil, otherwise use the specified one)
        if is_manual_execution && iteration == 1
          # First iteration of manual execution - use the specified agent
          next_agent = agent_name
          skip_stage = nil
        else
          # Automatic execution or subsequent iterations - determine from stage
          agent_info = LeadAgentService::StageManager.determine_next_agent(lead.stage, campaign: campaign)
          unless agent_info
            # No more agents to run or all remaining agents are disabled
            # Check if we're at final stage
            if lead.stage == AgentConstants::STAGE_DESIGNED || lead.stage == AgentConstants::STAGE_COMPLETED
              # Already at final stage - nothing to do
              break
            else
              # All remaining agents are disabled - lead cannot progress, return early
              Rails.logger.info("[LeadAgentService] All remaining agents are disabled for lead #{lead.id} at stage #{lead.stage} - lead cannot progress")
              return {
                status: "blocked",
                error: "All remaining agents in sequence are disabled. Lead cannot progress from stage '#{lead.stage}'.",
                outputs: {},
                lead: lead,
                completed_agents: [],
                failed_agents: []
              }
            end
          end

          next_agent = agent_info[:agent]
          skip_stage = agent_info[:skip_stage]

          # If we need to skip disabled agents, advance the stage first
          if skip_stage
            Rails.logger.info("[LeadAgentService] Skipping disabled agents in loop, advancing lead #{lead.id} from #{lead.stage} to #{skip_stage}")
            lead.update!(stage: skip_stage)
            lead.reload
            lead.association(:agent_outputs).reset
          end
        end

        # Get agent config for this campaign
        agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, next_agent)

        # Debug logging for agent config status
        Rails.logger.info("[LeadAgentService] Checking agent #{next_agent} for campaign #{campaign.id} (iteration #{iteration})")
        Rails.logger.info("[LeadAgentService] Agent config ID: #{agent_config&.id}, enabled value: #{agent_config&.enabled.inspect}")

        # Verify config belongs to the correct campaign (safety check)
        if agent_config && agent_config.campaign_id != campaign.id
          Rails.logger.error("[LeadAgentService] CRITICAL: Agent config #{agent_config.id} belongs to campaign #{agent_config.campaign_id}, but we're processing campaign #{campaign.id}")
          raise "Agent config campaign mismatch"
        end

        # If agent is disabled, block execution (this shouldn't happen if determine_next_agent worked correctly)
        is_disabled = agent_config && (agent_config.enabled == false || agent_config.disabled?)
        if is_disabled
          if is_manual_execution && iteration == 1
            # For manual execution: if user explicitly tries to run a disabled agent, return error
            Rails.logger.warn("[LeadAgentService] User attempted to manually run disabled agent #{next_agent}")
            return {
              status: "failed",
              error: "Agent #{next_agent} is disabled and cannot be run.",
              outputs: {},
              lead: lead,
              completed_agents: [],
              failed_agents: []
            }
          else
            # This shouldn't happen - determine_next_agent should have skipped this
            # But handle it gracefully by trying to skip again
            Rails.logger.warn("[LeadAgentService] Agent #{next_agent} is disabled but wasn't skipped - attempting to skip")
            agent_info = LeadAgentService::StageManager.determine_next_agent(lead.stage, campaign: campaign)
            if agent_info && agent_info[:agent] != next_agent
              # Found a different enabled agent - skip to it
              next_agent = agent_info[:agent]
              skip_stage = agent_info[:skip_stage]
              if skip_stage
                lead.update!(stage: skip_stage)
                lead.reload
                lead.association(:agent_outputs).reset
              end
              # Continue with the new agent
              next
            else
              # No enabled agents found
              return {
                status: "blocked",
                error: "Agent #{next_agent} is disabled and no enabled agents found. Lead cannot progress from stage '#{lead.stage}'.",
                outputs: {},
                lead: lead,
                completed_agents: [],
                failed_agents: []
              }
            end
          end
        end

        # Agent is enabled - execute it
        Rails.logger.info("[LeadAgentService] Agent #{next_agent} is enabled, proceeding with execution")

        # Reload lead to ensure we have latest data
        lead.reload
        lead.association(:agent_outputs).reset

        # Load previous outputs if needed
        previous_outputs = LeadAgentService::OutputManager.load_previous_outputs(lead, next_agent)

        # If running WRITER, check if this is a rewrite (has critique feedback available)
        previous_critique = nil
        if next_agent == AgentConstants::AGENT_WRITER
          Rails.logger.info("[LeadAgentService] WRITER agent selected - checking for critique feedback")
          Rails.logger.info("[LeadAgentService] Current lead stage: #{lead.stage}")
          Rails.logger.info("[LeadAgentService] Is written stage? #{lead.stage == AgentConstants::STAGE_WRITTEN}")
          Rails.logger.info("[LeadAgentService] Is rewritten stage? #{AgentConstants.rewritten_stage?(lead.stage)}")

          # Check if we're at written or rewritten stage with existing critique
          if lead.stage == AgentConstants::STAGE_WRITTEN || AgentConstants.rewritten_stage?(lead.stage)
            Rails.logger.info("[LeadAgentService] Stage check passed, looking for critique outputs...")

            # Get the LATEST critique output for feedback
            # Clear association cache first to ensure fresh query
            lead.association(:agent_outputs).reset
            critique_output = lead.agent_outputs
                                  .where(agent_name: AgentConstants::AGENT_CRITIQUE, status: AgentConstants::STATUS_COMPLETED)
                                  .order(created_at: :desc)
                                  .first

            Rails.logger.info("[LeadAgentService] Critique output found? #{critique_output.present?}")
            Rails.logger.info("[LeadAgentService] Critique output ID: #{critique_output.id if critique_output}")

            if critique_output
              output_data = critique_output.output_data || {}
              previous_critique = output_data["critique"] || output_data[:critique]
              critique_score = output_data["score"] || output_data[:score]

              Rails.logger.info("[LeadAgentService] 🔄 WRITER REVISION DETECTED - Running WRITER again with critique feedback")
              Rails.logger.info("[LeadAgentService] Critique score: #{critique_score}/10, Critique length: #{previous_critique&.length || 0} chars")
              if previous_critique
                Rails.logger.info("[LeadAgentService] Critique text preview: #{previous_critique.first(100)}...")
              end
              Rails.logger.info("[LeadAgentService] Passing critique feedback to WRITER for revision")
            else
              Rails.logger.warn("[LeadAgentService] No critique output found despite being at written/rewritten stage")
            end
          else
            Rails.logger.info("[LeadAgentService] WRITER running at stage '#{lead.stage}' - this is NOT a revision (initial write)")
          end
        end

        # Prepare agents hash for executor
        agents = {
          search: search_agent,
          writer: writer_agent,
          critique: critique_agent,
          design: design_agent
        }

        # Execute agent based on type, passing critique feedback if available
        result = if next_agent == AgentConstants::AGENT_WRITER && previous_critique.present?
                   LeadAgentService::Executor.execute_writer_agent(
                     writer_agent, lead, agent_config, previous_outputs[AgentConstants::AGENT_SEARCH],
                     previous_critique: previous_critique
                   )
        else
                   LeadAgentService::Executor.execute_agent(next_agent, agents, lead, agent_config, previous_outputs)
        end

        # Store output - this creates a NEW record each time
        saved_output = LeadAgentService::OutputManager.save_agent_output(lead, next_agent, result, AgentConstants::STATUS_COMPLETED)
        Rails.logger.info("[LeadAgentService] Saved #{next_agent} output: ID=#{saved_output.id}, total outputs for lead=#{lead.agent_outputs.where(agent_name: next_agent).count}")
        outputs[next_agent] = result
        completed_agents << next_agent

        # Handle stage advancement based on agent type
        old_stage_before_advance = lead.stage
        if next_agent == AgentConstants::AGENT_WRITER && previous_critique.present?
          # WRITER revision: Calculate rewrite count AFTER the new output is created
          # Reload to ensure we have the newly created WRITER output
          lead.reload
          lead.association(:agent_outputs).reset
          rewrite_count = LeadAgentService::StageManager.calculate_rewrite_count(lead)
          LeadAgentService::StageManager.set_rewritten_stage(lead, rewrite_count)
          Rails.logger.info("[LeadAgentService] WRITER revision completed, set stage to rewritten (#{rewrite_count})")
        elsif next_agent == AgentConstants::AGENT_CRITIQUE && result
          # CRITIQUE: Check if score meets minimum
          meets_min_score = result["meets_min_score"] || result[:meets_min_score] || false

          # Update lead quality
          LeadAgentService::StageManager.update_lead_quality(lead, result)

          if meets_min_score
            # Score meets minimum: advance to critiqued stage
            LeadAgentService::StageManager.advance_stage(lead, next_agent)
            Rails.logger.info("[LeadAgentService] Critique score meets minimum, advancing to critiqued stage")
          else
            # Score below minimum: If already at rewritten stage, stay there
            # Otherwise, set back to written stage to allow WRITER to run
            if AgentConstants.rewritten_stage?(lead.stage)
              # Already at rewritten stage - stay at current stage
              Rails.logger.warn("[LeadAgentService] Critique score below minimum, staying at #{lead.stage} for improvement")
            else
              # Not rewritten yet - set back to written so WRITER can run with feedback
              lead.update!(stage: AgentConstants::STAGE_WRITTEN)
              Rails.logger.warn("[LeadAgentService] Critique score below minimum, reverting to written stage for improvement")
            end
          end
        else
          # Normal stage advancement for other agents (SEARCH, WRITER, DESIGN)
          Rails.logger.info("[LeadAgentService] Advancing stage for agent #{next_agent} from #{old_stage_before_advance}")
          LeadAgentService::StageManager.advance_stage(lead, next_agent)
          lead.reload
          Rails.logger.info("[LeadAgentService] Stage advanced to #{lead.stage} after #{next_agent} execution")
        end

        lead.reload

        # Break out of loop after executing one agent successfully
        # The loop is only for skipping disabled agents, not for executing multiple agents
        break

      rescue => e
        # Store error output with appropriate fields based on agent type
        error_output = LeadAgentService::OutputManager.create_error_output(e, next_agent, lead)

        LeadAgentService::OutputManager.save_agent_output(lead, next_agent, error_output, AgentConstants::STATUS_FAILED)
        outputs[next_agent] = error_output
        failed_agents << next_agent

        # DO NOT advance stage if agent failed
        # Lead stays at current stage for retry
        break  # Exit loop on error
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
