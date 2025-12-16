class LeadRunExecutor
  require "set"
  require_relative "lead_runs/config_resolver"

  RUNNING_STEP_TIMEOUT = 15.minutes
  LLM_AGENT_NAMES = %w[SEARCH WRITER CRITIQUE DESIGN].freeze

  def self.run_next!(lead_run_id:, requested_agent_name: nil)
    new(lead_run_id: lead_run_id, requested_agent_name: requested_agent_name).run_next!
  end

  def initialize(lead_run_id:, requested_agent_name: nil)
    @lead_run_id = lead_run_id
    @requested_agent_name = requested_agent_name.presence
  end

  def run_next!
    if AgentExecution.paused?
      run = LeadRun.find_by(id: @lead_run_id)
      return { result_type: :paused, run_id: @lead_run_id, run_status: run&.status || "unknown" }
    end

    action = claim_or_prepare_action!

    if action[:result_type] == :finalize
      step = LeadRunStep.find(action[:step_id])
      run = step.lead_run
      output = AgentOutput.find(action[:output_id])
      return finalize_from_output!(run: run, step: step, output: output, source: :existing_output)
    end

    return action unless action[:result_type] == :claimed

    step = LeadRunStep.find(action[:claimed_step_id])
    run = step.lead_run

    existing_output = AgentOutput.find_by(lead_run_step_id: step.id)
    if existing_output
      return finalize_from_output!(run: run, step: step, output: existing_output, source: :existing_output)
    end

    begin
      output_data =
        ActiveSupport::Notifications.instrument(
          "lead_runs.step_executed",
          run_id: run.id,
          step_id: step.id,
          agent_name: step.agent_name,
          rewrite_count: run.rewrite_count
        ) do
          execute_step!(run: run, step: step)
        end

      # Check if agent returned an error hash (e.g., network errors from CritiqueAgent)
      # Treat it as a failure, not a success
      # Use error_type as primary indicator (network errors include error_type: "network")
      # This is more explicit than checking retryable, which could theoretically be in success payloads
      is_error_hash = output_data.is_a?(Hash) && (output_data["error_type"] || output_data[:error_type]).present?

      if is_error_hash
        # This is an error response, not a successful completion
        # Extract error metadata from the hash
        error_msg = output_data["error"] || output_data[:error] || output_data["detail"] || output_data[:detail] || "Agent returned error"
        retryable = output_data["retryable"] || output_data[:retryable] || false
        error_code_from_hash = output_data["error_code"] || output_data[:error_code]
        error_type_from_hash = output_data["error_type"] || output_data[:error_type]
        provider_error_from_hash = output_data["provider_error"] || output_data[:provider_error]
        provider_from_hash = output_data["provider"] || output_data[:provider]
        request_id_from_hash = output_data["request_id"] || output_data[:request_id]
        occurred_at_from_hash = output_data["occurred_at"] || output_data[:occurred_at]

        # Try to find existing output to merge into
        existing_output = AgentOutput.find_by(lead_run_step_id: step.id)
        data = existing_output ? (existing_output.output_data || {}).dup : {}
        data.merge!(
          "error" => error_msg,
          "message" => error_msg,
          "retryable" => retryable
        )
        data["error_code"] = error_code_from_hash if error_code_from_hash
        data["error_type"] = error_type_from_hash if error_type_from_hash
        data["provider_error"] = provider_error_from_hash if provider_error_from_hash
        data["provider"] = provider_from_hash if provider_from_hash
        data["request_id"] = request_id_from_hash if request_id_from_hash
        data["occurred_at"] = occurred_at_from_hash if occurred_at_from_hash

        if existing_output
          existing_output.update!(
            output_data: data,
            status: "failed",
            error_message: error_msg.to_s.truncate(500)
          )
          output = existing_output
        else
          output = persist_output_race_safe!(
            run: run,
            step: step,
            output_data: data,
            status: "failed",
            error_message: error_msg.to_s.truncate(500)
          )
        end
      else
        # Normal success path
        output = persist_output_race_safe!(run: run, step: step, output_data: output_data, status: "completed")
      end
    rescue => e
      error_code =
        case e.message
        when "sending_not_configured_at_send_time", "missing_source_step_id", "missing_send_source_output"
          e.message
        else
          e.class.name
        end

      # Extract retryable flag, error_code, error_type, provider_error, and debug bundle if exception supports it
      # (from CritiqueAgent API errors)
      retryable = e.respond_to?(:retryable?) ? e.retryable? : false
      error_code_from_exception = e.respond_to?(:error_code) ? e.error_code : nil
      error_type_from_exception = e.respond_to?(:error_type) ? e.error_type : nil
      provider_error_from_exception = e.respond_to?(:provider_error) ? e.provider_error : nil
      provider_from_exception = e.respond_to?(:provider) ? e.provider : nil
      request_id_from_exception = e.respond_to?(:request_id) ? e.request_id : nil
      occurred_at_from_exception = e.respond_to?(:occurred_at) ? e.occurred_at : nil

      # Always merge into existing output_data if it exists (don't clobber)
      existing_output = AgentOutput.find_by(lead_run_step_id: step.id)
      data = existing_output ? (existing_output.output_data || {}).dup : {}
      data.merge!(
        "error" => error_code,
        "message" => e.message.to_s.truncate(200),
        "retryable" => retryable
      )

      # Include error details and debug bundle if available from exception (for API errors)
      data["error_code"] = error_code_from_exception if error_code_from_exception
      data["error_type"] = error_type_from_exception if error_type_from_exception
      data["provider_error"] = provider_error_from_exception if provider_error_from_exception
      data["provider"] = provider_from_exception if provider_from_exception
      data["request_id"] = request_id_from_exception if request_id_from_exception
      data["occurred_at"] = occurred_at_from_exception if occurred_at_from_exception

      if existing_output
        existing_output.update!(
          output_data: data,
          status: "failed",
          error_message: e.message.to_s.truncate(500)
        )
        output = existing_output
      else
        output = persist_output_race_safe!(
          run: run,
          step: step,
          output_data: data,
          status: "failed",
          error_message: e.message.to_s.truncate(500)
        )
      end
    end

    finalize_from_output!(run: run, step: step, output: output, source: :fresh_execution)
  end

  private

  # Txn A: strictly serialized per run.
  # - stale-running recovery first (atomic)
  # - if a non-stale running step exists:
  #   - if it already has an AgentOutput, finalize it (idempotent recovery)
  #   - else return nothing_to_do
  # - else claim the next queued step (SKIP LOCKED)
  def claim_or_prepare_action!
    result = nil

    ActiveRecord::Base.transaction do
      run = LeadRun.lock.find(@lead_run_id)
      Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} status=#{run.status} starting Txn A")

      stale_result = recover_stale_running_step_or_prepare_finalize!(run)
      if stale_result
        result = stale_result
        next
      end

      running_step = run.steps.where(status: "running").order(:position).first
      if running_step
        output = AgentOutput.find_by(lead_run_step_id: running_step.id)
        if output
          Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} step_id=#{running_step.id} preparing finalize from existing output")
          result = { result_type: :finalize, step_id: running_step.id, output_id: output.id }
        else
          result = {
            result_type: :nothing_to_do,
            run_id: run.id,
            run_status: run.status,
            running_step_id: running_step.id,
            running_agent_name: running_step.agent_name
          }
        end
        next
      end

      step = claimable_next_step_after_skips!(run)

      unless step
        result = { result_type: :nothing_to_do, run_id: run.id, run_status: run.status }
        next
      end

      resolved = LeadRuns::ConfigResolver.resolve(campaign: run.campaign, agent_name: step.agent_name)
      unless resolved[:enabled]
        # Config may have flipped disabled after we scanned; skip and try again.
        skip_step_as_disabled!(run: run, step: step, resolved: resolved)
        step = claimable_next_step_after_skips!(run)
        unless step
          result = { result_type: :nothing_to_do, run_id: run.id, run_status: run.status }
          next
        end
        resolved = LeadRuns::ConfigResolver.resolve(campaign: run.campaign, agent_name: step.agent_name)
      end

      if @requested_agent_name.present? && step.agent_name.to_s != @requested_agent_name.to_s
        result = {
          result_type: :blocked_wrong_next_step,
          run_id: run.id,
          run_status: run.status,
          requested_agent_name: @requested_agent_name,
          next_agent_name: step.agent_name
        }
        next
      end

      # Snapshot settings at claim-time. If a snapshot already exists, keep it stable.
      step.update!(
        status: "running",
        step_started_at: Time.current,
        meta: meta_with_settings_snapshot(step: step, resolved: resolved)
      )
      run.update!(started_at: Time.current, status: "running") if run.started_at.nil?

      Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} claimed step_id=#{step.id} agent=#{step.agent_name}")
      result = {
        result_type: :claimed,
        run_id: run.id,
        run_status: run.status,
        claimed_step_id: step.id,
        claimed_agent_name: step.agent_name
      }
    end

    result || { result_type: :nothing_to_do, run_id: @lead_run_id }
  end

  def claimable_next_step_after_skips!(run)
    loop do
      step =
        run.steps
           .where(status: "queued")
           .order(:position)
           .limit(1)
           .lock("FOR UPDATE SKIP LOCKED")
           .first

      return nil unless step

      next if skip_step_if_disabled!(run: run, step: step)

      return step
    end
  end

  def skip_step_if_disabled!(run:, step:)
    return false unless step.status.to_s == "queued"

    resolved = LeadRuns::ConfigResolver.resolve(campaign: run.campaign, agent_name: step.agent_name)
    return false if resolved[:enabled]

    # Make the transition explicitly conditional to avoid double-skips if the
    # step changed status between selection and update.
    step.reload
    return false unless step.status.to_s == "queued"

    skip_step_as_disabled!(run: run, step: step, resolved: resolved)
    Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} step_id=#{step.id} agent=#{step.agent_name} skipped (disabled)")
    true
  end

  def skip_step_as_disabled!(run:, step:, resolved:)
    meta = (step.meta || {}).dup
    meta["skip_reason"] = "agent_disabled"
    meta["skipped_at"] = Time.current.iso8601
    meta["skipped_agent_name"] = step.agent_name.to_s
    meta["config_id"] = resolved[:config_id] if resolved.key?(:config_id)
    if resolved[:config_updated_at]
      meta["config_updated_at"] = resolved[:config_updated_at].iso8601
    end

    step.update!(status: "skipped", step_finished_at: Time.current, meta: meta)
  end

  def meta_with_settings_snapshot(step:, resolved:)
    meta = (step.meta || {}).dup

    existing =
      meta["settings_snapshot"] ||
      meta[:settings_snapshot]

    return meta if existing.present?

    meta["settings_snapshot"] = resolved[:settings_snapshot] || {}
    meta["settings_snapshot_at"] = Time.current.iso8601
    meta["config_id"] = resolved[:config_id] if resolved.key?(:config_id)
    meta["config_updated_at"] = resolved[:config_updated_at].iso8601 if resolved[:config_updated_at]
    meta
  end

  def recover_stale_running_step_or_prepare_finalize!(run)
    threshold = Time.current - RUNNING_STEP_TIMEOUT
    corrupted = run.steps.where(status: "running", step_started_at: nil).order(:position).first
    if corrupted
      # A running step must have a start timestamp. Treat this as corruption
      # (do not auto-fail it as stale), and surface it for investigation.
      Rails.logger.error("[LeadRunExecutor] run_id=#{run.id} corrupted_running_step_missing_started_at step_id=#{corrupted.id} agent=#{corrupted.agent_name}")
    end

    stale = run.steps.where(status: "running").where("step_started_at IS NOT NULL AND step_started_at < ?", threshold).order(:position).first
    return nil unless stale

    # Phase 3.3: RISK D mitigation - Exclude SENDER steps with enqueue_job_id from stale recovery
    # These are waiting on EmailSendingJob, not stuck
    if stale.agent_name == AgentConstants::AGENT_SENDER
      meta = stale.meta || {}
      enqueue_job_id = meta["enqueue_job_id"] || meta[:enqueue_job_id]
      if enqueue_job_id.present?
        Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} step_id=#{stale.id} agent=SENDER has enqueue_job_id=#{enqueue_job_id}; skipping stale recovery (waiting on job)")
        return nil
      end

      # For SENDER without enqueue_job_id, extend timeout significantly (1 hour instead of 15 minutes)
      # This gives jobs more time to complete
      extended_threshold = Time.current - 1.hour
      if stale.step_started_at >= extended_threshold
        Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} step_id=#{stale.id} agent=SENDER within extended timeout; skipping stale recovery")
        return nil
      end
    end

    output = AgentOutput.find_by(lead_run_step_id: stale.id)
    if output
      Rails.logger.warn("[LeadRunExecutor] run_id=#{run.id} stale running step_id=#{stale.id} has output; preparing finalize instead of timeout")
      return { result_type: :finalize, step_id: stale.id, output_id: output.id }
    end

    Rails.logger.warn("[LeadRunExecutor] run_id=#{run.id} stale running step_id=#{stale.id} agent=#{stale.agent_name} recovering via timeout fail")

    timeout_output = persist_output_race_safe!(
      run: run,
      step: stale,
      output_data: { "error" => "timeout" },
      status: "failed",
      error_message: "timeout"
    )

    stale.update!(
      status: "failed",
      agent_output: timeout_output,
      step_finished_at: Time.current
    )

    run.update!(status: "failed", finished_at: Time.current)
    run.lead.update!(current_lead_run: nil) if run.lead.current_lead_run_id == run.id

    {
      result_type: :failed_timeout_recovery,
      run_id: run.id,
      run_status: run.status,
      failed_step_id: stale.id,
      failed_agent_name: stale.agent_name
    }
  end

  def execute_step!(run:, step:)
    if step.agent_name == AgentConstants::AGENT_SENDER
      source_step_id =
        (step.meta || {})["source_step_id"] ||
        (step.meta || {})[:source_step_id]

      raise "missing_source_step_id" if source_step_id.blank?

      unless sending_configured_now?(run.lead)
        raise "sending_not_configured_at_send_time"
      end

      # Ensure the source output exists (auditable + prevents silent sends).
      source_output = AgentOutput.find_by(lead_run_step_id: source_step_id)
      raise "missing_send_source_output" unless source_output

      # Enqueue job with step_id
      job = EmailSendingJob.perform_later(run.lead.id, step.id)

      # Store enqueue_job_id in step.meta inside transaction with output persistence
      # This ensures output saying "enqueued" has meta link (no orphaned state)
      ActiveRecord::Base.transaction do
        meta = (step.meta || {}).dup
        meta["enqueue_job_id"] = job.job_id
        meta["enqueued_at"] = Time.current.iso8601
        step.update!(meta: meta)
      end

      Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} step_id=#{step.id} enqueued EmailSendingJob job_id=#{job.job_id} source_step_id=#{source_step_id}")

      return {
        "enqueued" => true,
        "enqueue_job_id" => job.job_id,
        "job_id" => job.job_id, # Also include in output_data for audit trail
        "source_step_id" => source_step_id
      }
    end

    if LLM_AGENT_NAMES.include?(step.agent_name)
      return AgentDispatcher.dispatch!(lead_run: run, step: step)
    end

    raise NotImplementedError, "Unknown step type: #{step.agent_name}"
  end

  def persist_output_race_safe!(run:, step:, output_data:, status: "completed", error_message: nil)
    AgentOutput.create!(
      lead: run.lead,
      lead_run: run,
      lead_run_step: step,
      agent_name: step.agent_name,
      status: status,
      error_message: error_message,
      output_data: output_data || { "error" => "missing_output_data" }
    )
  rescue ActiveRecord::RecordNotUnique
    AgentOutput.find_by!(lead_run_step_id: step.id)
  end

  def finalize_from_output!(run:, step:, output:, source:)
    ActiveRecord::Base.transaction do
      locked_step = LeadRunStep.lock.find(step.id)
      locked_run = LeadRun.lock.find(run.id)

      # Monotonic transitions: never rewrite terminal steps.
      if locked_step.status.in?(%w[completed failed])
        return {
          result_type: :noop_step_already_terminal,
          run_id: locked_run.id,
          run_status: locked_run.status,
          step_id: locked_step.id,
          step_status: locked_step.status,
          agent_name: locked_step.agent_name
        }
      end

      # Only transition running -> terminal.
      unless locked_step.status == "running"
        return {
          result_type: :noop_step_not_running,
          run_id: locked_run.id,
          run_status: locked_run.status,
          step_id: locked_step.id,
          step_status: locked_step.status,
          agent_name: locked_step.agent_name
        }
      end

      outcome = determine_outcome!(locked_run: locked_run, step: locked_step, output: output)

      # Align output row with outcome if needed.
      if outcome[:output_updates]
        output.update!(outcome[:output_updates])
      end

      # Only set step_finished_at for terminal statuses (completed/failed)
      step_update = {
        status: outcome[:step_status],
        agent_output: output
      }
      if outcome[:step_status].in?(%w[completed failed])
        step_update[:step_finished_at] = Time.current
      end

      locked_step.update!(step_update)

      update_stage_projection!(lead: locked_run.lead, step: locked_step, output: output)

      enforce_run_status!(run: locked_run)

      if locked_run.status.in?(LeadRun::TERMINAL_STATUSES)
        locked_run.lead.update!(current_lead_run: nil) if locked_run.lead.current_lead_run_id == locked_run.id
      end

      {
        result_type: source == :existing_output ? :finalized_from_existing_output : :finalized,
        run_id: locked_run.id,
        run_status: locked_run.status,
        step_id: locked_step.id,
        step_status: locked_step.status,
        agent_name: locked_step.agent_name
      }
    end
  end

  def determine_outcome!(locked_run:, step:, output:)
    if step.agent_name == AgentConstants::AGENT_CRITIQUE
      score = parse_score(output.output_data)
      if score.nil?
        # Preserve original error message if it exists, otherwise use generic message
        existing_error = output.error_message || output.output_data&.dig("message") || output.output_data&.dig(:message)
        error_message = existing_error || "score_parse_failed"

        # If error message is too long, truncate it but keep the important part
        if error_message.length > 500
          error_message = error_message[0..497] + "..."
        end

        return {
          step_status: "failed",
          output_updates: {
            status: "failed",
            error_message: error_message,
            output_data: (output.output_data || {}).merge("error" => "score_parse_failed", "message" => error_message)
          }
        }
      end

      # Store canonical normalized score as integer (clamped 0..10).
      #
      # Contract: meets_min_score is computed by executor based on score >= threshold.
      # This ensures consistency: meets_min_score always reflects the authoritative threshold check.
      #
      # We preserve the agent's original value (if present) as raw_meets_min_score for debugging,
      # and store the computed threshold_used for auditability.
      #
      # IMPORTANT: Threshold is frozen per step - read from step.meta (stored at claim-time),
      # NOT recomputed from current config. This guarantees deterministic audit trail even if
      # configs change mid-run.
      original_data = output.output_data || {}
      raw_meets_min_score = original_data["meets_min_score"] || original_data[:meets_min_score]

      # Determine threshold from same source used for comparison (deterministic audit trail)
      # Read from step.meta (frozen at claim-time), not from current config
      step_meta = step.meta || {}
      settings_snapshot = step_meta["settings_snapshot"] || step_meta[:settings_snapshot] || {}
      threshold_from_snapshot = settings_snapshot["min_score_for_send"] || settings_snapshot[:min_score_for_send]

      # Determine threshold source and pointer, then ensure threshold_used is always an Integer
      # This prevents nil threshold from causing comparison failures
      raw_threshold = if !threshold_from_snapshot.nil?
        threshold_source = "settings_snapshot"
        threshold_source_pointer = "lead_run_steps.meta.settings_snapshot.min_score_for_send"
        threshold_from_snapshot
      else
        threshold_source = "run.min_score"
        threshold_source_pointer = "lead_runs.min_score"
        locked_run.min_score
      end

      # Always ensure threshold_used is an Integer (default to 0 if both sources are nil)
      threshold_used = (raw_threshold.nil? ? 0 : raw_threshold).to_i
      threshold_was_nil = raw_threshold.nil?

      computed_meets_min_score = score >= threshold_used

      # Store config metadata for auditability (if thresholds change mid-run)
      step_config_id = step_meta["agent_config_id"] || step_meta[:agent_config_id]
      step_config_updated_at = step_meta["agent_config_updated_at"] || step_meta[:agent_config_updated_at]

      normalized = original_data.merge(
        "score" => score,
        "meets_min_score" => computed_meets_min_score,  # Authoritative computed value
        "threshold_used" => threshold_used,  # The threshold used for computation (always Integer, default 0 if nil)
        "threshold_was_nil" => threshold_was_nil,  # Flag indicating if threshold was nil (for debugging)
        "raw_meets_min_score" => raw_meets_min_score,  # Original agent value (if present) for debugging
        "threshold_source" => threshold_source,  # Source of threshold for auditability
        "threshold_source_pointer" => threshold_source_pointer  # Detailed pointer for faster debugging
      )

      # Store config metadata if available (for mid-run threshold change audits)
      normalized["agent_config_id"] = step_config_id if step_config_id
      normalized["agent_config_updated_at"] = step_config_updated_at if step_config_updated_at

      if computed_meets_min_score
        return {
          step_status: "completed",
          output_updates: { status: "completed", output_data: normalized }
        }
      end

      # Below min score → rewrite loop or fail (v1).
      if locked_run.rewrite_count < locked_run.max_rewrites
        unless rewrite_already_inserted?(run: locked_run, critique_step_id: step.id)
          insert_rewrite_steps!(run: locked_run, failing_critique_step: step)
        end

        return {
          step_status: "completed",
          output_updates: { status: "completed", output_data: normalized }
        }
      end

      # No rewrites remaining (v1): fail the run.
      return {
        step_status: "failed",
        output_updates: {
          status: "failed",
          error_message: "min_score_not_met",
          output_data: normalized.merge("error" => "min_score_not_met")
        }
      }
    end

    if step.agent_name == AgentConstants::AGENT_SENDER
      data = output.output_data || {}
      enqueued = data["enqueued"] || data[:enqueued]

      # Phase 4.1: Keep SENDER step running after enqueue; job will finalize it
      if enqueued == true
        # Step should remain running, not completed
        # Only EmailSendingJob (Phase 3.2) marks it completed/failed
        # Note: AgentOutput status stays "pending" (not "running") - only LeadRunStep can be "running"
        return {
          step_status: "running", # Keep step running, not completed
          output_updates: {
            # Don't update status - keep it as "pending" until EmailSendingJob completes
            # AgentOutput only allows pending/completed/failed, not "running"
            output_data: data.merge("email_status" => "queued") # Track delivery state
          }
        }
      end

      return { step_status: "failed", output_updates: { status: "failed" } }
    end

    # Non-CRITIQUE LLM steps: exception paths persist output.status='failed' above.
    return { step_status: "failed", output_updates: { status: "failed" } } if output.status == "failed"

    # Non-CRITIQUE v1: successful output means completed; exceptions are handled earlier.
    { step_status: "completed", output_updates: { status: "completed" } }
  end

  def enforce_run_status!(run:)
    any_failed = run.steps.where(status: "failed").exists?
    if any_failed
      run.update!(status: "failed", finished_at: Time.current)
      # Note: lead.stage is intentionally NOT updated here.
      # Stage represents progression state (e.g., "rewritten (1)"), while run.status represents success/failure.
      # This allows UI to show both: stage = where we got to, run_status = whether it succeeded.
      return
    end

    # Phase 4.3: Prevent run completion while SENDER unresolved
    # Check for any steps in queued/running status (includes SENDER waiting on EmailSendingJob)
    any_in_progress = run.steps.where(status: %w[queued running]).exists?
    if !any_in_progress
      run.update!(status: "completed", finished_at: Time.current)
      return
    end

    run.update!(status: "running") if run.status != "running"
  end

  ##
  # Public method for recomputing run status after external updates (e.g., from EmailSendingJob)
  # This ensures single source of truth for run finalization
  #
  # @param run_id [Integer] The run ID to recompute
  def self.recompute_run_status!(run_id:)
    run = LeadRun.find_by(id: run_id)
    return unless run

    ActiveRecord::Base.transaction do
      locked_run = LeadRun.lock.find(run.id)
      locked_lead = locked_run.lead

      # Recompute run status
      any_failed = locked_run.steps.where(status: "failed").exists?
      if any_failed
        locked_run.update!(status: "failed", finished_at: Time.current) unless locked_run.status == "failed"
      else
        any_in_progress = locked_run.steps.where(status: %w[queued running]).exists?
        if !any_in_progress
          locked_run.update!(status: "completed", finished_at: Time.current) unless locked_run.status == "completed"
        else
          locked_run.update!(status: "running") if locked_run.status != "running"
        end
      end

      # Clear current_lead_run_id if run is terminal
      if locked_run.status.in?(LeadRun::TERMINAL_STATUSES)
        if locked_lead.current_lead_run_id == locked_run.id
          locked_lead.update!(current_lead_run: nil)
        end
      end
    end
  end

  def rewrite_already_inserted?(run:, critique_step_id:)
    run.steps
       .where(agent_name: AgentConstants::AGENT_WRITER)
       .where("meta ->> 'critique_step_id' = ?", critique_step_id.to_s)
       .exists?
  end

  # Inserts WRITER + CRITIQUE directly after the failing critique step using gapped positions.
  # Deterministic tie-break: choose smallest available integers > p (ascending) for WRITER then CRITIQUE.
  def insert_rewrite_steps!(run:, failing_critique_step:)
    run.update!(rewrite_count: run.rewrite_count + 1)
    revision = run.rewrite_count
    Rails.logger.info("[LeadRunExecutor] run_id=#{run.id} inserting rewrite revision=#{revision} after critique_step_id=#{failing_critique_step.id}")

    writer_pos, critique_pos = choose_insertion_positions!(run: run, failing_step: failing_critique_step)

    writer_step = LeadRunStep.create!(
      lead_run: run,
      position: writer_pos,
      agent_name: AgentConstants::AGENT_WRITER,
      status: "queued",
      meta: {
        "revision" => revision,
        "critique_step_id" => failing_critique_step.id
      }
    )

    LeadRunStep.create!(
      lead_run: run,
      position: critique_pos,
      agent_name: AgentConstants::AGENT_CRITIQUE,
      status: "queued",
      meta: {
        "writer_step_id" => writer_step.id,
        "selected_variant_index" => 0
      }
    )
  end

  def choose_insertion_positions!(run:, failing_step:)
    failing_step.reload

    p = failing_step.position
    next_step = run.steps.where("position > ?", p).order(:position).first
    next_p = next_step ? next_step.position : (p + 30)

    # Need two positions strictly between p and next_p.
    used = run.steps.pluck(:position).to_set
    available = ((p + 1)...next_p).reject { |pos| used.include?(pos) }.to_a
    return [ available[0], available[1] ] if available.length >= 2

    renormalize_positions!(run: run)

    failing_step.reload
    p = failing_step.position
    next_step = run.steps.where("position > ?", p).order(:position).first
    next_p = next_step ? next_step.position : (p + 30)

    used = run.steps.pluck(:position).to_set
    available = ((p + 1)...next_p).reject { |pos| used.include?(pos) }.to_a
    raise "No space to insert rewrite steps" if available.length < 2
    [ available[0], available[1] ]
  end

  def renormalize_positions!(run:)
    ordered = run.steps.order(:position).to_a
    pos = 10
    ordered.each do |step|
      step.update!(position: pos)
      pos += 10
    end
  end

  def parse_score(output_data)
    data = output_data || {}
    raw = data["score"] || data[:score]
    return nil if raw.nil?

    num =
      case raw
      when Integer
        raw
      when Float
        raw.floor
      when String
        s = raw.strip
        if s.match?(/\A-?\d+\z/)
          s.to_i
        elsif (m = s.match(/\A(-?\d+)\s*\/\s*\d+\z/))
          m[1].to_i
        elsif (m = s.match(/\A(-?\d+)(?:\.\d+)?\z/))
          m[1].to_i
        else
          nil
        end
      else
        nil
      end

    return nil if num.nil?

    [ [ num, 0 ].max, 10 ].min
  end

  def sending_configured_now?(lead)
    user = lead.campaign&.user
    return false unless user

    result = EmailDeliveryConfig.check(user: user, campaign: lead.campaign)
    result[:ok]
  end

  def update_stage_projection!(lead:, step:, output:)
    return unless lead

    case step.agent_name
    when AgentConstants::AGENT_SEARCH
      lead.update!(stage: AgentConstants::STAGE_SEARCHED) if step.status == "completed"
    when AgentConstants::AGENT_WRITER
      if step.status == "completed"
        # Check if this is a rewrite (has revision in meta)
        # Support both string and symbol keys (like SettingsHelper pattern)
        meta = step.meta || {}
        revision = meta["revision"] || meta[:revision]

        if revision && revision.to_i > 0
          # This is a rewrite - set stage to "rewritten (N)"
          # Stage represents "last completed milestone artifact" - rewrite WRITER completion is a milestone
          rewritten_stage = AgentConstants.rewritten_stage_name(revision.to_i)
          lead.update!(stage: rewritten_stage)
          Rails.logger.info("[LeadRunExecutor] Updated lead stage to #{rewritten_stage} after rewrite WRITER completion (revision=#{revision})")
        else
          # Original WRITER - set to "written"
          lead.update!(stage: AgentConstants::STAGE_WRITTEN)
        end
      end
    when AgentConstants::AGENT_CRITIQUE
      # LeadRuns source-of-truth projection into the lead record:
      # - Keep `leads.quality` as a UI-friendly projection derived from CRITIQUE output
      # - Normalize critique text: "None"/"N/A"/empty → nil, store critique_present flag
      output_data = output.output_data || {}
      critique = output_data["critique"] || output_data[:critique]

      # Normalize critique: treat "None", "N/A", empty strings as nil (no feedback = perfect email)
      # Conservative normalization: exact match only (trim + casefold), not substring match.
      # This prevents false positives if model returns "None" as part of actual feedback.
      # Handles punctuation variants like "None." or "N/A." by stripping trailing punctuation only.
      normalized_critique = if critique.nil?
        nil
      else
        trimmed = critique.to_s.strip
        if trimmed.empty?
          nil
        else
          # Strip trailing punctuation/spaces only (handles "None." / "N/A." without breaking "None of...")
          candidate = trimmed.downcase.gsub(/\A[[:punct:]\s]+|[[:punct:]\s]+\z/, "")
          if [ "none", "n/a", "na" ].include?(candidate)
            nil
          else
            trimmed  # Keep actual feedback text (trimmed)
          end
        end
      end

      critique_present = normalized_critique.present?

      # Update output_data with normalized critique and presence flag (if changed)
      if output_data["critique"] != normalized_critique || output_data["critique_present"] != critique_present
        output.update!(output_data: output_data.merge(
          "critique" => normalized_critique,
          "critique_present" => critique_present
        ))
      end

      # Quality projection: if critique is nil/empty, treat as "high" quality, else "medium"
      quality = normalized_critique.nil? ? "high" : "medium"
      lead.update!(quality: quality) if step.status == "completed" && lead.quality != quality

      # Stage represents "last completed milestone artifact"
      # CRITIQUE completion is a milestone regardless of pass/fail
      # Pass/fail is tracked in output_data["meets_min_score"] and lead.quality, not in stage
      if step.status == "completed"
        lead.update!(stage: AgentConstants::STAGE_CRITIQUED)
      end
    when AgentConstants::AGENT_DESIGN
      lead.update!(stage: AgentConstants::STAGE_DESIGNED) if step.status == "completed"
    when AgentConstants::AGENT_SENDER
      # Phase 5.2: Remove stage=completed logic from executor for SENDER
      # EmailSendingJob owns all stage updates for delivery outcomes (Phase 5.1)
      # Do not update stage here - let EmailSendingJob handle it
    end
  end
end
