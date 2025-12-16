module LeadRuns
  # Error classes for send-only run creation
  class RunInProgressError < StandardError
    attr_reader :run_id, :next_agent
    def initialize(run_id:, next_agent:)
      @run_id = run_id
      @next_agent = next_agent
      super("run_in_progress")
    end
  end

  class SenderNotPlannedError < StandardError
    attr_reader :reason
    def initialize(reason:)
      @reason = reason
      super("sender_not_planned")
    end
  end

  class SendingNotConfiguredError < StandardError
    attr_reader :reasons
    def initialize(reasons:)
      @reasons = reasons
      super("sending_not_configured")
    end
  end

  class AlreadySendingError < StandardError
    attr_reader :step_id, :run_id
    def initialize(step_id:, run_id:)
      @step_id = step_id
      @run_id = run_id
      super("already_sending")
    end
  end

  def self.status_payload_for(lead, run: nil, campaign: nil, agent_configs: nil)
    run = run || resolve_active_run_for_payload(lead)

    # Use provided campaign or fall back to lead.campaign
    campaign ||= lead.campaign

    # Stable “no run” payload (no legacy mode concept).
    unless run
      can_send = can_send_without_run?(lead, campaign)
      return {
        run_id: nil,
        run_status: "none",
        running_step: nil,
        last_completed_step: nil,
        next_step: (can_send ? Struct.new(:id, :agent_name).new(nil, AgentConstants::AGENT_SENDER) : nil),
        rewrite_count: 0,
        lead_stage: lead.stage,
        can_send: can_send
      }
    end

    # Reconcile disabled queued steps to skipped before computing next_step
    reconcile_disabled_steps!(run, campaign)
    run.reload

    running_step = run.steps.find { |s| s.status == "running" }
    last_completed = run.steps.select { |s| s.status == "completed" }.max_by(&:position)
    next_step = next_runnable_step(run, campaign: campaign, agent_configs: agent_configs, lead: lead)

    {
      run_id: run.id,
      run_status: run.status,
      running_step: running_step ? step_payload(running_step) : nil,
      last_completed_step: last_completed ? step_payload(last_completed) : nil,
      next_step: next_step ? step_payload(next_step) : nil,
      rewrite_count: run.rewrite_count,
      lead_stage: lead.stage,
      can_send: can_send_for_lead?(lead, campaign, next_step)
    }
  end

  # Helper to determine if sending is allowed for a lead
  def self.can_send_for_lead?(lead, campaign, next_step)
    # Only allow sending if next step is SENDER
    return false unless next_step&.agent_name == AgentConstants::AGENT_SENDER

    # Check if sending is actually configured
    delivery_result = EmailDeliveryConfig.check(user: campaign.user, campaign: campaign)
    delivery_result[:ok]
  end

  def self.step_payload(step)
    # Handle both actual LeadRunStep objects, OpenStruct (virtual steps), and hash representations
    if step.nil?
      nil
    elsif step.is_a?(Hash)
      step
    elsif step.respond_to?(:agent_name) && step.respond_to?(:id)
      { id: step.id, agent_name: step.agent_name }
    else
      nil
    end
  end

  # Read-only helper: determine the next runnable queued step, ignoring queued steps
  # whose agent is currently disabled for the campaign.
  #
  # This keeps UI/actions correct even if configs are toggled after a run is planned.
  def self.next_runnable_step(run, campaign:, agent_configs: nil, lead: nil)
    # Find next enabled queued step
    run.steps
       .select { |s| s.status == "queued" }
       .sort_by(&:position)
       .find { |step| agent_enabled?(campaign, step.agent_name, agent_configs: agent_configs) }
  end

  # Helper to check if a lead is in a sent stage (sent (1), sent (2), etc.)
  def self.sent_stage?(lead)
    lead.stage.to_s.start_with?(AgentConstants::STAGE_SENT_PREFIX)
  end

  # Helper to check if a lead is in a final stage (sent or failed)
  def self.final_stage?(lead)
    sent_stage?(lead) || lead.stage.to_s == AgentConstants::STAGE_SEND_FAILED
  end

  # Helper to determine if sending is allowed when there's no active run.
  # This allows users to retry Send after a failed run has been cleared.
  #
  # @param lead [Lead] The lead to check
  # @param campaign [Campaign] The campaign containing agent configs
  # @return [Boolean] True if sending is allowed without an active run
  def self.can_send_without_run?(lead, campaign)
    # Allow retry after send_failed; block only if already sent.
    return false if sent_stage?(lead)

    sender_cfg = find_agent_config(campaign, AgentConstants::AGENT_SENDER)
    return false unless sender_cfg&.enabled?

    delivery = EmailDeliveryConfig.check(user: campaign.user, campaign: campaign)
    return false unless delivery[:ok]

    # Lightweight existence check for any usable source output
    AgentOutput
      .where(lead_id: lead.id, status: "completed", agent_name: [ AgentConstants::AGENT_DESIGN, AgentConstants::AGENT_WRITER ])
      .where("output_data->>'formatted_email' IS NOT NULL OR output_data->>'email' IS NOT NULL")
      .exists?
  end

  def self.agent_enabled?(campaign, agent_name, agent_configs: nil)
    # SENDER is special-cased throughout the codebase: missing config => disabled.
    if agent_name.to_s == AgentConstants::AGENT_SENDER
      cfg = find_agent_config(campaign, agent_name, agent_configs: agent_configs)
      return cfg.present? && cfg.enabled?
    end

    cfg = find_agent_config(campaign, agent_name, agent_configs: agent_configs)

    # For non-SENDER agents, treat missing config as enabled (default behavior) without auto-creating.
    return true unless cfg

    cfg.enabled?
  end

  # DB-truth lookup for the current active run (queued/running).
  #
  # In early rollout commits the LeadRun model/associations may not exist yet;
  # this method is written to be safe to load even before migrations land.
  def self.active_run_for(lead)
    return nil unless defined?(LeadRun)

    LeadRun.where(lead_id: lead.id, status: %w[queued running]).order(created_at: :desc).first
  end

  # Convenience wrapper used by controllers/jobs once LeadRunPlanner exists.
  #
  # Contract (implemented in later commits):
  # - return existing active run if present (DB truth)
  # - else create one via planner atomically
  # - handle concurrent creation by rescuing unique violations and re-querying
  def self.ensure_active_run_for!(lead)
    run = active_run_for(lead)
    return run if run

    begin
      LeadRunPlanner.build!(lead: lead)
    rescue ActiveRecord::RecordNotUnique
      # Concurrent creation: partial unique index may be hit under double-clicks/batch jobs.
      active_run_for(lead) || raise
    end
  end

  # Prefer a preloaded active run pointer to avoid N+1 on list views.
  def self.resolve_active_run_for_payload(lead)
    return nil unless defined?(LeadRun)

    # If current_lead_run is loaded and active, use it (avoids per-lead query).
    if lead.respond_to?(:current_lead_run) && (run = lead.current_lead_run)
      if run.respond_to?(:status) && run.status.in?(LeadRun::ACTIVE_STATUSES)
        return run
      end
    end

    lead.active_run
  end

  def self.find_agent_config(campaign, agent_name, agent_configs: nil)
    # Use provided preloaded configs if available
    if agent_configs
      return agent_configs.find { |c| c.agent_name.to_s == agent_name.to_s }
    end

    # Prefer preloaded association to avoid N+1 in list views.
    if campaign.respond_to?(:agent_configs) && campaign.association(:agent_configs).loaded?
      return campaign.agent_configs.find { |c| c.agent_name.to_s == agent_name.to_s }
    end

    AgentConfig.find_by(campaign_id: campaign.id, agent_name: agent_name)
  rescue NameError
    # During early boot/migrations, be conservative.
    nil
  end

  ##
  # Reconciles disabled queued steps to "skipped" status.
  # This ensures that steps for disabled agents don't block run progression.
  #
  # Note: This only handles queued steps, not running steps. If an agent is disabled
  # while a step is running, the step will complete normally. The UI/admin should
  # prevent disabling agents when there are running steps.
  #
  # @param run [LeadRun] The run to reconcile
  # @param campaign [Campaign] The campaign containing agent configs
  def self.reconcile_disabled_steps!(run, campaign)
    disabled_agent_names = campaign.agent_configs.where(enabled: false).pluck(:agent_name)
    return if disabled_agent_names.empty?

    now = Time.current
    steps_to_update = run.steps.where(status: "queued", agent_name: disabled_agent_names)

    if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      # Use JSONB operators for efficient bulk update
      updated_count = steps_to_update.update_all(
        status: "skipped",
        step_finished_at: now,
        updated_at: now,
        # record skip reason in meta so we can reverse it safely
        meta: Arel.sql("COALESCE(meta, '{}'::jsonb) || '{\"skip_reason\":\"disabled\"}'::jsonb")
      )
    else
      # Ruby-side fallback for non-PostgreSQL databases
      updated_count = 0
      steps_to_update.find_each do |step|
        meta = (step.meta || {}).dup
        meta["skip_reason"] = "disabled"
        step.update!(
          status: "skipped",
          step_finished_at: now,
          updated_at: now,
          meta: meta
        )
        updated_count += 1
      end
    end

    if updated_count > 0
      Rails.logger.info("[LeadRuns.reconcile_disabled_steps!] Marked #{updated_count} disabled queued step(s) as skipped run_id=#{run.id} disabled_agents=#{disabled_agent_names.inspect}")
    end
  end

  ##
  # Reconciles enabled steps that were previously skipped due to being disabled.
  # This allows steps to be requeued when their agent is re-enabled.
  #
  # @param run [LeadRun] The run to reconcile
  # @param campaign [Campaign] The campaign containing agent configs
  def self.reconcile_enabled_steps!(run, campaign)
    enabled_agent_names = campaign.agent_configs.where(enabled: true).pluck(:agent_name)
    return if enabled_agent_names.empty?

    now = Time.current
    steps_to_update = run.steps.where(status: "skipped", agent_name: enabled_agent_names)

    if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      # Use JSONB operators for efficient bulk update
      steps_to_update
        .where("meta ->> 'skip_reason' = 'disabled'")
        .update_all(
          status: "queued",
          step_started_at: nil,
          step_finished_at: nil,
          updated_at: now,
          meta: Arel.sql("COALESCE(meta, '{}'::jsonb) - 'skip_reason'")
        )
    else
      # Ruby-side fallback for non-PostgreSQL databases
      steps_to_update.find_each do |step|
        meta = step.meta || {}
        next unless meta["skip_reason"] == "disabled" || meta[:skip_reason] == "disabled"

        new_meta = meta.dup
        new_meta.delete("skip_reason")
        new_meta.delete(:skip_reason)

        step.update!(
          status: "queued",
          step_started_at: nil,
          step_finished_at: nil,
          updated_at: now,
          meta: new_meta
        )
      end
    end
  end

  ##
  # Ensures a DESIGN step exists in the run, inserting it before SENDER if needed.
  # This handles cases where DESIGN was disabled when the run plan was created.
  #
  # @param run [LeadRun] The run to ensure DESIGN step in
  def self.ensure_design_step!(run)
    # Gate: Only insert if SENDER hasn't finished (don't insert DESIGN after sending)
    sender_finished = run.steps.where(agent_name: "SENDER", status: %w[completed failed]).exists?
    return if sender_finished

    # Use lock to prevent concurrent double-insert race conditions
    run.with_lock do
      # If any DESIGN step already exists (any status), don't create duplicates.
      return if run.steps.where(agent_name: "DESIGN").exists?

      sender_step = run.steps.where(agent_name: "SENDER", status: "queued").order(:position).first

      # If no queued sender, just append
      if sender_step.nil?
        pos = (run.steps.maximum(:position) || 0) + 10
        run.steps.create!(agent_name: "DESIGN", status: "queued", position: pos, meta: {})
        return
      end

      # Handle position edge case: if sender position is 0 or 1, resequence first
      # to ensure we have safe gaps for insertion
      if sender_step.position <= 1
        resequence_positions!(run)
        sender_step.reload
      end

      # Try to insert right before sender
      insert_pos = sender_step.position - 1

      # If that slot is taken, resequence to create gaps, then insert again
      if run.steps.where(position: insert_pos).exists?
        resequence_positions!(run)
        sender_step.reload
        insert_pos = sender_step.position - 1
      end

      run.steps.create!(
        agent_name: "DESIGN",
        status: "queued",
        position: insert_pos,
        meta: {}
      )
    end
  end

  ##
  # Resequences step positions to create gaps (10, 20, 30...) for easier insertion.
  #
  # Note: This method updates updated_at for all steps via update_columns, which can
  # affect "recent changes" UI if position is used for audit purposes. Position is
  # primarily used for internal ordering, so this side effect is acceptable.
  #
  # @param run [LeadRun] The run to resequence
  def self.resequence_positions!(run)
    steps = run.steps.order(:position).to_a
    steps.each_with_index do |s, idx|
      # 10, 20, 30... gives you room to insert later
      s.update_columns(position: (idx + 1) * 10, updated_at: Time.current)
    end
  end

  ##
  # Finds a valid source step (DESIGN or WRITER) with completed output for SENDER.
  # Used both for validating source availability and repairing stale source_step_id references.
  #
  # @param lead [Lead] The lead to find source step for
  # @return [LeadRunStep] The source step (DESIGN with formatted_email/email, or WRITER with email)
  # @raise [PlannerError] If no valid source step is found
  def self.find_send_source_step_for!(lead)
    # Find latest completed DESIGN step that has an output with content
    design_step = LeadRunStep.joins(:lead_run)
                              .joins("INNER JOIN agent_outputs ON agent_outputs.lead_run_step_id = lead_run_steps.id")
                              .where(lead_runs: { lead_id: lead.id })
                              .where(agent_name: AgentConstants::AGENT_DESIGN, status: "completed")
                              .where("agent_outputs.status = ?", "completed")
                              .where("agent_outputs.output_data->>'formatted_email' IS NOT NULL OR agent_outputs.output_data->>'email' IS NOT NULL")
                              .order(created_at: :desc)
                              .first

    # Fallback to WRITER if no DESIGN
    source_step = design_step
    unless source_step
      source_step = LeadRunStep.joins(:lead_run)
                                .joins("INNER JOIN agent_outputs ON agent_outputs.lead_run_step_id = lead_run_steps.id")
                                .where(lead_runs: { lead_id: lead.id })
                                .where(agent_name: AgentConstants::AGENT_WRITER, status: "completed")
                                .where("agent_outputs.status = ?", "completed")
                                .where("agent_outputs.output_data->>'email' IS NOT NULL")
                                .order(created_at: :desc)
                                .first
    end

    unless source_step
      raise LeadRunPlanner::PlannerError.new("send_source_missing")
    end

    # Validate source output exists and has content (should exist due to JOIN, but verify)
    source_output = AgentOutput.find_by(lead_run_step_id: source_step.id)
    unless source_output
      raise LeadRunPlanner::PlannerError.new("send_source_missing")
    end

    # Validate output contains content fields
    output_data = source_output.output_data || {}
    has_content = output_data["formatted_email"].present? ||
                  output_data[:formatted_email].present? ||
                  output_data["email"].present? ||
                  output_data[:email].present?

    unless has_content
      raise LeadRunPlanner::PlannerError.new("send_source_missing")
    end

    source_step
  end

  ##
  # Ensures a sendable run exists for SENDER requests.
  # This prevents the 422 error by creating send-only runs when appropriate.
  #
  # RISK A mitigation: Checks for active run first to prevent clobbering.
  #
  # @param lead [Lead] The lead to create run for
  # @param requested_agent_name [String] The requested agent (must be SENDER)
  # @return [LeadRun] The active run (existing or newly created)
  # @raise [PlannerError] If SENDER is not enabled/configured or source output is missing
  def self.ensure_sendable_run!(lead:, requested_agent_name:, sender_user: nil)
    unless requested_agent_name.to_s == AgentConstants::AGENT_SENDER
      # For non-SENDER requests, fall back to standard ensure_active_run!
      return ensure_active_run_for!(lead)
    end

    campaign = lead.campaign
    user = sender_user || campaign.user

    # RISK A: Serialize on the lead to prevent race conditions
    # This prevents "double send-only run creation" and stale reads of step state
    # The lock ensures atomicity: check active run -> reconcile -> decide -> validate -> create (if needed)
    #
    # Lock ordering: Always lock lead first, then run (lead → run) to prevent deadlocks.
    # If other code locks run then lead (opposite order), deadlocks can occur.
    lead.with_lock do
      # First check active run to prevent clobbering
      # Reuse active runs where only SENDER remains as the active step
      active_run = active_run_for(lead)
      if active_run
        # Lock the run to prevent concurrent modifications (nested lock: lead → run)
        active_run.lock!

        # Reconcile disabled queued steps to skipped (safety net)
        reconcile_disabled_steps!(active_run, campaign)
        active_run.reload

        # Get all active (queued/running) steps, ordered by position
        active_steps = active_run.steps.where(status: %w[queued running]).order(:position)

        # Explicitly check for non-SENDER and SENDER active steps
        non_sender_active = active_steps.where.not(agent_name: AgentConstants::AGENT_SENDER)
        sender_active = active_steps.where(agent_name: AgentConstants::AGENT_SENDER)

        # Validate SENDER enablement and delivery config BEFORE reusing run
        # This ensures we return user-friendly 422 errors even when reusing existing runs
        sender_config = find_agent_config(campaign, AgentConstants::AGENT_SENDER)
        unless sender_config&.enabled?
          reason = sender_config ? "config_disabled" : "config_missing"
          raise SenderNotPlannedError.new(reason: reason)
        end

        delivery_result = EmailDeliveryConfig.check(user: user, campaign: campaign)
        unless delivery_result[:ok]
          raise SendingNotConfiguredError.new(reasons: delivery_result[:reasons])
        end

        # Race/double-click guard: If SENDER is already running, raise AlreadySendingError
        sender_running = sender_active.where(status: "running").order(:position).first
        if sender_running
          raise AlreadySendingError.new(
            step_id: sender_running.id,
            run_id: active_run.id
          )
        end

        # If the only remaining active step is SENDER, we can safely reuse this run.
        # This handles both "send-only runs" (single step) and pipeline runs at the last step (SENDER queued).
        # Explicitly require: no non-SENDER active steps AND SENDER active steps exist
        # Use !exists? instead of none? to avoid accidental relation loads
        if !non_sender_active.exists? && sender_active.exists?
          # Only SENDER is active - reuse the run
          # BUT: Repair source_step_id if it points to a skipped/missing-output step
          # (e.g., if DESIGN was disabled after SENDER was created, the source_step_id may be invalid)
          sender_step = sender_active.order(:position).first
          planned_source_id = sender_step.meta && sender_step.meta["source_step_id"]

          planned_ok =
            if planned_source_id
              ao = AgentOutput.where(lead_run_step_id: planned_source_id, status: "completed").order(created_at: :desc).first
              if ao
                data = ao.output_data || {}
                data["formatted_email"].present? || data[:formatted_email].present? ||
                data["email"].present? || data[:email].present?
              else
                false
              end
            else
              false
            end

          unless planned_ok
            # Recompute source step (DESIGN with content, else WRITER with content)
            # This handles cases where DESIGN was disabled and the original source step is now skipped
            source_step = find_send_source_step_for!(lead)
            sender_step.update!(meta: (sender_step.meta || {}).merge("source_step_id" => source_step.id))
            Rails.logger.info(
              "[LeadRuns.ensure_sendable_run!] Repaired source_step_id for sender_step_id=#{sender_step.id} " \
              "from invalid planned_source_id=#{planned_source_id} to valid source_step_id=#{source_step.id}"
            )
          end

          return active_run
        end

        # If there are non-SENDER active steps, we should block.
        if non_sender_active.exists?
          first_active = active_steps.first
          raise RunInProgressError.new(
            run_id: active_run.id,
            next_agent: first_active&.agent_name
          )
        end

        # No active steps - run is completed/failed, proceed to create new send-only run
      end

      # Validate SENDER enablement (for new run creation path)
      sender_config = find_agent_config(campaign, AgentConstants::AGENT_SENDER)
      unless sender_config&.enabled?
        reason = sender_config ? "config_disabled" : "config_missing"
        raise SenderNotPlannedError.new(reason: reason)
      end

      # Validate sending configuration (for new run creation path)
      delivery_result = EmailDeliveryConfig.check(user: user, campaign: campaign)
      unless delivery_result[:ok]
        raise SendingNotConfiguredError.new(reasons: delivery_result[:reasons])
      end

      # Strict eligibility check: find source output (DESIGN or WRITER)
      # Note: These joins are inside the lock for correctness (atomicity), but they are potentially
      # heavy operations. For high-traffic scenarios, consider computing source_step before the lock
      # (read-only), then re-checking it still exists inside the lock (quick check by id).
      source_step = find_send_source_step_for!(lead)

      # Phase 8.1: Idempotency guard - check for existing SENDER step with email_status in queued/sending/retrying
      existing_sender_step = LeadRunStep.joins(:agent_output, :lead_run)
                                        .where(lead_runs: { lead_id: lead.id })
                                        .where(agent_name: AgentConstants::AGENT_SENDER)
                                        .where("agent_outputs.output_data->>'email_status' IN (?)", [ "queued", "sending", "retrying" ])
                                        .where("lead_run_steps.status IN (?)", [ "queued", "running" ])
                                        .order(created_at: :desc)
                                        .first

      if existing_sender_step
        # Already sending - return error
        raise AlreadySendingError.new(
          step_id: existing_sender_step.id,
          run_id: existing_sender_step.lead_run_id
        )
      end

      # Note: We already checked for active runs with only SENDER above.
      # This section is only reached if there's no active run or the active run has no active steps.

      # Create send-only run
      run = LeadRun.create!(
        lead: lead,
        campaign: campaign,
        status: "queued",
        rewrite_count: 0,
        min_score: 0, # Not used for send-only runs
        max_rewrites: 0, # Not used for send-only runs
        plan: { "steps" => [ { "agent_name" => AgentConstants::AGENT_SENDER } ] },
        config_snapshot: {}
      )

      sender_step = LeadRunStep.create!(
        lead_run: run,
        position: 10,
        agent_name: AgentConstants::AGENT_SENDER,
        status: "queued",
        meta: { "source_step_id" => source_step.id }
      )

      lead.update!(current_lead_run: run)

      run
    end
  rescue ActiveRecord::RecordNotUnique
    # Concurrent creation - re-query
    active_run_for(lead) || raise
  end
end
