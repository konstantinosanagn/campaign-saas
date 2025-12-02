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
  # Skips disabled agents and finds the next enabled one
  # If a disabled agent is skipped, returns the agent and the stage to advance to
  #
  # @param current_stage [String] The current stage of the lead
  # @param campaign [Campaign, nil] The campaign to check agent configs (optional)
  # @return [Hash, nil] Hash with :agent (agent name), :skip_stage (stage to advance to if agent is disabled), or nil if at final stage
  def self.determine_next_agent(current_stage, campaign: nil)
    stage_index = AgentConstants::STAGE_PROGRESSION.index(current_stage)
    return nil if stage_index.nil? || stage_index >= AgentConstants::STAGE_PROGRESSION.length - 1

    # Map stage to next agent and target stage
    # queued -> SEARCH (to become 'searched')
    # searched -> WRITER (to become 'written')
    # written -> CRITIQUE (to become 'critiqued')
    # critiqued -> DESIGN (to become 'designed')
    # designed -> nil (final stage)
    agent_stage_map = {
      AgentConstants::STAGE_QUEUED => { agent: AgentConstants::AGENT_SEARCH, target_stage: AgentConstants::STAGE_SEARCHED },
      AgentConstants::STAGE_SEARCHED => { agent: AgentConstants::AGENT_WRITER, target_stage: AgentConstants::STAGE_WRITTEN },
      AgentConstants::STAGE_WRITTEN => { agent: AgentConstants::AGENT_CRITIQUE, target_stage: AgentConstants::STAGE_CRITIQUED },
      AgentConstants::STAGE_CRITIQUED => { agent: AgentConstants::AGENT_DESIGN, target_stage: AgentConstants::STAGE_DESIGNED }
    }

    mapping = agent_stage_map[current_stage]
    return nil unless mapping

    next_agent = mapping[:agent]
    target_stage = mapping[:target_stage]

    # If campaign is provided, check if agents are enabled
    # Skip disabled agents and find the next enabled one
    if campaign
      current_stage_check = current_stage
      skipped_stages = []  # Track stages we've skipped through
      max_iterations = 5  # Safety limit
      iteration = 0

      while iteration < max_iterations
        iteration += 1
        current_mapping = agent_stage_map[current_stage_check]
        break unless current_mapping

        check_agent = current_mapping[:agent]
        check_target_stage = current_mapping[:target_stage]

        agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, check_agent)

        if agent_config.enabled?
          # Found an enabled agent
          if skipped_stages.any?
            # We skipped some agents - return the agent and the final stage to advance to
            final_skip_stage = skipped_stages.last
            Rails.logger.info("[StageManager] Found enabled agent #{check_agent} after skipping disabled agents. Will advance through: #{skipped_stages.join(' -> ')}")
            return { agent: check_agent, skip_stage: final_skip_stage }
          else
            # Next agent is enabled, no skipping needed
            return { agent: check_agent }
          end
        else
          # Agent is disabled - skip it and check the next stage
          Rails.logger.info("[StageManager] Agent #{check_agent} is disabled, will skip to stage #{check_target_stage}")
          skipped_stages << check_target_stage
          current_stage_check = check_target_stage

          # Check if we've reached the final stage
          if current_stage_check == AgentConstants::STAGE_DESIGNED || current_stage_check == AgentConstants::STAGE_COMPLETED
            Rails.logger.info("[StageManager] All remaining agents are disabled, reached final stage")
            return nil
          end
        end
      end

      # If we exhausted iterations, return nil
      Rails.logger.warn("[StageManager] Exhausted iterations while checking for enabled agents")
      return nil
    end

    # No campaign provided - return the next agent without checking enabled status
    { agent: next_agent }
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

  ##
  # Calculates the rewrite count for a lead
  # Counts WRITER outputs created after the first CRITIQUE output
  #
  # @param lead [Lead] The lead to calculate rewrite count for
  # @return [Integer] The number of rewrites (0 if no critiques or no rewrites yet)
  def self.calculate_rewrite_count(lead)
    # Reload to ensure fresh data
    lead.reload

    # Find first CRITIQUE output (chronologically)
    first_critique = lead.agent_outputs
                         .where(agent_name: AgentConstants::AGENT_CRITIQUE, status: AgentConstants::STATUS_COMPLETED)
                         .order(created_at: :asc)
                         .first

    unless first_critique
      Rails.logger.info("[StageManager] No CRITIQUE output found for lead #{lead.id}, rewrite count = 0")
      return 0
    end

    Rails.logger.info("[StageManager] First CRITIQUE output for lead #{lead.id}: ID=#{first_critique.id}, created_at=#{first_critique.created_at}")

    # Count WRITER outputs created after the first critique
    rewrite_count = lead.agent_outputs
                        .where(agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED)
                        .where("created_at > ?", first_critique.created_at)
                        .count

    # Log all WRITER outputs for debugging
    all_writer_outputs = lead.agent_outputs
                             .where(agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED)
                             .order(created_at: :asc)
                             .pluck(:id, :created_at)
    Rails.logger.info("[StageManager] All WRITER outputs for lead #{lead.id}: #{all_writer_outputs.map { |id, ts| "ID=#{id} @ #{ts}" }.join(', ')}")
    Rails.logger.info("[StageManager] Rewrite count for lead #{lead.id}: #{rewrite_count} (WRITER outputs created after first CRITIQUE at #{first_critique.created_at})")

    rewrite_count
  end

  ##
  # Sets the lead stage to a rewritten stage with the given count
  #
  # @param lead [Lead] The lead to update
  # @param rewrite_count [Integer] The rewrite count (1, 2, 3, etc.)
  def self.set_rewritten_stage(lead, rewrite_count)
    new_stage = AgentConstants.rewritten_stage_name(rewrite_count)
    lead.update!(stage: new_stage)
    Rails.logger.info("[StageManager] Set lead #{lead.id} to rewritten stage: #{new_stage}")
  end

  ##
  # Determines available actions for a lead based on its current state
  # Returns an array of available agent names that can be run
  # Filters out disabled agents - only returns enabled agents
  #
  # @param lead [Lead] The lead to determine actions for
  # @return [Array<String>] Array of available agent names (only enabled agents)
  def self.determine_available_actions(lead)
    actions = []

    # Reload to ensure fresh data
    lead.reload
    lead.association(:agent_outputs).reset

    # Get campaign for agent config checks (reload to ensure fresh association)
    campaign = lead.campaign
    campaign.reload if campaign

    # Compute key state variables upfront
    latest_critique = latest_completed_critique(lead)
    meets_min       = critique_meets_min_score(latest_critique)
    rewrite_count   = calculate_rewrite_count(lead)

    current_stage = lead.stage

    Rails.logger.info("[StageManager] Lead #{lead.id}: stage=#{current_stage}, meets_min=#{meets_min.inspect}, rewrite_count=#{rewrite_count}")

    # Helper method to check if agent is enabled and add to actions if so
    # If disabled, returns false - we don't skip ahead because workflow requires sequential stages
    add_action_if_enabled = lambda do |agent_name|
      agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, agent_name)
      if agent_config.enabled?
        actions << agent_name
        Rails.logger.info("[StageManager] Lead #{lead.id}: Adding enabled agent #{agent_name} to actions")
        true
      else
        Rails.logger.info("[StageManager] Lead #{lead.id}: Agent #{agent_name} is disabled - no action available (cannot skip workflow stages)")
        false
      end
    end

    # Handle rewritten stages first (special case)
    # At rewritten stage, we need to check if the critique was done AFTER the latest WRITER
    if AgentConstants.rewritten_stage?(current_stage)
      latest_writer = latest_completed_writer(lead)
      critique_is_newer = latest_critique && latest_writer && latest_critique.created_at > latest_writer.created_at

      Rails.logger.info("[StageManager] Lead #{lead.id}: rewritten stage check - latest_critique_id=#{latest_critique&.id}, latest_writer_id=#{latest_writer&.id}, critique_is_newer=#{critique_is_newer}")

      if !critique_is_newer
        # No critique after the latest rewrite → need to run CRITIQUE
        Rails.logger.info("[StageManager] Lead #{lead.id}: rewritten stage, no critique after latest writer → CRITIQUE")
        add_action_if_enabled.call(AgentConstants::AGENT_CRITIQUE)
      elsif meets_min == false
        # Critique done after rewrite but still failed → need another rewrite
        Rails.logger.info("[StageManager] Lead #{lead.id}: rewritten stage, critique after writer but failed → WRITER")
        add_action_if_enabled.call(AgentConstants::AGENT_WRITER)
      else
        # Critique done after rewrite and passed → advance to DESIGN
        Rails.logger.info("[StageManager] Lead #{lead.id}: rewritten stage, critique after writer and passed → DESIGN")
        add_action_if_enabled.call(AgentConstants::AGENT_DESIGN)
      end

      # Summary log for rewritten stage
      Rails.logger.info(
        "[StageManager] Actions for lead #{lead.id} at stage=#{lead.stage} " \
        "rewrite_count=#{rewrite_count}, meets_min=#{meets_min.inspect}, " \
        "critique_is_newer=#{critique_is_newer}, latest_critique_id=#{latest_critique&.id} => #{actions.inspect}"
      )
      return actions.uniq
    end

    # Main stage-based logic
    case current_stage
    when AgentConstants::STAGE_QUEUED
      add_action_if_enabled.call(AgentConstants::AGENT_SEARCH)

    when AgentConstants::STAGE_SEARCHED
      add_action_if_enabled.call(AgentConstants::AGENT_WRITER)

    when AgentConstants::STAGE_WRITTEN
      if latest_critique.nil?
        # 1) Written, never critiqued → first CRITIQUE
        Rails.logger.info("[StageManager] Lead #{lead.id}: written, never critiqued → CRITIQUE")
        add_action_if_enabled.call(AgentConstants::AGENT_CRITIQUE)

      elsif meets_min == false && rewrite_count.zero?
        # 2) Critiqued, score below min, NO rewrites yet → show WRITER for rewrite
        Rails.logger.info("[StageManager] Lead #{lead.id}: written, critique failed, no rewrites yet → WRITER")
        add_action_if_enabled.call(AgentConstants::AGENT_WRITER)

      elsif meets_min == false && rewrite_count.positive?
        # 3) Critiqued, score still below min, but at least one rewrite happened → CRITIQUE again
        Rails.logger.info("[StageManager] Lead #{lead.id}: written, critique failed, has #{rewrite_count} rewrite(s) → CRITIQUE")
        add_action_if_enabled.call(AgentConstants::AGENT_CRITIQUE)

      else
        # Edge case: written but critique already "good" → advance to DESIGN
        Rails.logger.info("[StageManager] Lead #{lead.id}: written but critique passed → DESIGN")
        add_action_if_enabled.call(AgentConstants::AGENT_DESIGN)
      end

    when AgentConstants::STAGE_CRITIQUED
      if meets_min == false
        # Edge case: at critiqued stage but critique actually failed → WRITER
        Rails.logger.info("[StageManager] Lead #{lead.id}: critiqued but critique failed → WRITER")
        add_action_if_enabled.call(AgentConstants::AGENT_WRITER)
      else
        # Normal flow: critique passed → DESIGN
        add_action_if_enabled.call(AgentConstants::AGENT_DESIGN)
      end

    when AgentConstants::STAGE_DESIGNED
      # Design complete, ready to send (no agent action, handled by email sender)
      # Return empty - UI will show send button
      Rails.logger.info("[StageManager] Lead #{lead.id}: designed, ready to send")

    when AgentConstants::STAGE_COMPLETED
      # All done, no actions available
      Rails.logger.info("[StageManager] Lead #{lead.id}: completed, no actions")

    else
      # Unknown stage - try to determine next agent
      agent_info = determine_next_agent(current_stage, campaign: campaign)
      if agent_info && agent_info[:agent]
        add_action_if_enabled.call(agent_info[:agent])
      end
    end

    # Final summary log - shows exactly what button the UI should display
    Rails.logger.info(
      "[StageManager] Actions for lead #{lead.id} at stage=#{lead.stage} " \
      "rewrite_count=#{rewrite_count}, meets_min=#{meets_min.inspect}, " \
      "latest_critique_id=#{latest_critique&.id} => #{actions.inspect}"
    )

    actions.uniq
  end

  ##
  # Advances lead to the stage corresponding to the agent that just completed
  # This ensures that when agents are skipped, the stage reflects the actual agent that ran
  # Updated to handle rewritten stages
  #
  # @param lead [Lead] The lead to advance
  # @param agent_name [String] The agent that just completed
  def self.advance_stage(lead, agent_name)
    # If at a rewritten stage, handle specially
    if AgentConstants.rewritten_stage?(lead.stage)
      # From rewritten stage, normal progression goes to critiqued
      if agent_name == AgentConstants::AGENT_CRITIQUE
        lead.update!(stage: AgentConstants::STAGE_CRITIQUED)
        return
      end
    end

    # Map agent to its target stage (the stage that agent sets when it completes)
    # This ensures that when agents are skipped, the stage reflects the actual agent that ran
    agent_to_stage_map = {
      AgentConstants::AGENT_SEARCH => AgentConstants::STAGE_SEARCHED,
      AgentConstants::AGENT_WRITER => AgentConstants::STAGE_WRITTEN,
      AgentConstants::AGENT_CRITIQUE => AgentConstants::STAGE_CRITIQUED,
      AgentConstants::AGENT_DESIGN => AgentConstants::STAGE_DESIGNED
    }

    target_stage = agent_to_stage_map[agent_name]

    if target_stage
      # Set stage directly to the target stage for this agent
      # This ensures that if SEARCH was skipped and WRITER runs, stage becomes "written" not "searched"
      Rails.logger.info("[StageManager] Agent #{agent_name} completed, setting stage to #{target_stage}")
      lead.update!(stage: target_stage)
    else
      # Fallback: if agent not in map, use old progression logic
      Rails.logger.warn("[StageManager] Unknown agent #{agent_name}, using fallback progression")
      current_index = AgentConstants::STAGE_PROGRESSION.index(lead.stage) || -1
      next_index = current_index + 1

      # Only advance if not already at the final stage
      if next_index < AgentConstants::STAGE_PROGRESSION.length
        new_stage = AgentConstants::STAGE_PROGRESSION[next_index]
        lead.update!(stage: new_stage)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Private helper methods
  # ─────────────────────────────────────────────────────────────────────────────

  ##
  # Gets the latest completed CRITIQUE agent output for a lead
  #
  # @param lead [Lead] The lead to check
  # @return [AgentOutput, nil] The latest completed critique output or nil
  def self.latest_completed_critique(lead)
    lead.agent_outputs
        .where(agent_name: AgentConstants::AGENT_CRITIQUE, status: AgentConstants::STATUS_COMPLETED)
        .order(created_at: :desc)
        .first
  end

  ##
  # Gets the latest completed WRITER agent output for a lead
  #
  # @param lead [Lead] The lead to check
  # @return [AgentOutput, nil] The latest completed writer output or nil
  def self.latest_completed_writer(lead)
    lead.agent_outputs
        .where(agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED)
        .order(created_at: :desc)
        .first
  end

  ##
  # Gets the meets_min_score value from a critique output
  #
  # @param critique_output [AgentOutput, nil] The critique output to check
  # @return [Boolean, nil] true if score meets minimum, false if below, nil if no critique
  def self.critique_meets_min_score(critique_output)
    return nil unless critique_output

    output_data = critique_output.output_data || {}

    # IMPORTANT: Can't use || here because false || x returns x
    # Need to check key existence explicitly
    if output_data.key?("meets_min_score")
      output_data["meets_min_score"]
    elsif output_data.key?(:meets_min_score)
      output_data[:meets_min_score]
    else
      nil
    end
  end

  ##
  # Checks if a critique output indicates the email failed to meet minimum score
  #
  # @param critique_output [AgentOutput, nil] The critique output to check
  # @return [Boolean] true if critique failed (score below minimum), false otherwise
  def self.critique_failed?(critique_output)
    critique_meets_min_score(critique_output) == false
  end

  private_class_method :latest_completed_critique, :latest_completed_writer, :critique_meets_min_score, :critique_failed?
end
