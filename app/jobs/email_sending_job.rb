##
# EmailSendingJob
#
# Background job for sending emails to leads. This prevents blocking
# the HTTP request while emails are sent, which is critical for batch operations.
#
# Usage:
#   EmailSendingJob.perform_later(lead_id)
#   EmailSendingJob.perform_later(lead_id, lead_run_step_id)  # With SENDER step tracking
#
require_relative "../errors/email_errors"

class EmailSendingJob < ApplicationJob
  queue_as :default

  retry_on TemporaryEmailError, wait: 30.seconds, attempts: 5
  discard_on PermanentEmailError
  discard_on ArgumentError

  ##
  # Sends email to a lead in the background
  #
  # @param lead_id [Integer] The ID of the lead to send email to
  # @param lead_run_step_id [Integer, nil] Optional SENDER step ID for tracking
  def perform(lead_id, lead_run_step_id = nil)
    lead = Lead.find_by(id: lead_id)

    unless lead
      Rails.logger.warn("[EmailSendingJob] Lead #{lead_id} not found; skipping")
      return
    end

    step = nil
    output = nil
    run = nil
    if lead_run_step_id
      step = LeadRunStep.find_by(id: lead_run_step_id)
      output = AgentOutput.find_by(lead_run_step_id: lead_run_step_id) if step
      run = step&.lead_run
      
      unless step && step.agent_name == AgentConstants::AGENT_SENDER
        Rails.logger.warn("[EmailSendingJob] Step #{lead_run_step_id} not found or not SENDER; continuing without step tracking")
        step = nil
        output = nil
        run = nil
      end
    end

    # Update status to sending if step tracking
    # Note: AgentOutput status stays "pending" until completion/failure
    # The "running" state is tracked in LeadRunStep, not AgentOutput
    if step && output
      output.update!(
        output_data: (output.output_data || {}).merge("email_status" => "sending")
        # Don't update status here - keep it as "pending" until completion
      )
    end

    # RISK B: Calculate send_number BEFORE sending (count completed SENDER steps with email_status="sent")
    # This ensures we count previous sends, not including the current one
    send_number = if step
      # Count completed SENDER steps where status=completed AND output_data.email_status="sent"
      # This is robust against retries (retries don't create multiple completed steps)
      # Query AgentOutput directly - it belongs_to :lead, so we can filter by lead_id
      previous_sends = AgentOutput.where(lead_id: lead.id)
                                   .where(agent_name: AgentConstants::AGENT_SENDER, status: "completed")
                                   .where("output_data->>'email_status' = ?", "sent")
                                   .where.not(lead_run_step_id: step.id) # Exclude current step
                                   .joins(:lead_run_step)
                                   .where(lead_run_steps: { status: "completed" }) # Ensure step is also completed
                                   .count
      previous_sends + 1
    else
      1 # First send if no step tracking
    end

    # Track email sending outcome
    email_sent = false
    email_failed = false
    send_result = nil
    provider = "smtp" # default
    
    begin
      # Get email payload
      service = EmailSenderService.new(lead)
      subject, text_body, html_body = service.send(:build_email_payload)
      
      # Call send_email_via_provider directly to capture result
      # This now returns Gmail result hash or nil for SMTP
      # Note: This does NOT update lead.email_status or lead.stage (that's our job)
      send_result = EmailSenderService.send_email_via_provider(lead, subject, text_body, html_body)
      
      # Determine provider from result
      if send_result.is_a?(Hash) && (send_result["id"] || send_result[:id])
        provider = "gmail_api"
      else
        # Check service's default_provider for fallback
        provider = service.send(:default_provider)
      end
      
      # Mark as sent (will be finalized in ensure block)
      email_sent = true
      
      # Success path: update step/output and lead.stage
      if step && output
        # Extract metadata from send_result (Gmail returns message_id, SMTP doesn't)
        message_id = nil
        if send_result.is_a?(Hash)
          message_id = send_result["id"] || send_result[:id]
        end

        # Get from_email and to_email
        from_email = lead.campaign&.user&.send_from_email.presence || lead.campaign&.user&.email
        to_email = lead.email

        # Update output_data with delivery metadata
        output_data = (output.output_data || {}).dup
        output_data.merge!(
          "email_status" => "sent",
          "send_number" => send_number, # Store computed value, never changes
          "email_sent_at" => Time.current.iso8601,
          "sent_at" => Time.current.iso8601,
          "provider" => provider,
          "message_id" => message_id,
          "from_email" => from_email,
          "to_email" => to_email,
          "job_id" => job_id,
          "enqueue_job_id" => (step.meta || {})["enqueue_job_id"]
        )

        # Update step and output
        step.update!(status: "completed", step_finished_at: Time.current)
        output.update!(
          status: "completed",
          output_data: output_data
        )

        # Update lead.stage to "sent (n)" and email_status
        lead.update!(
          stage: "sent (#{send_number})",
          email_status: "sent",
          last_email_sent_at: Time.current,
          last_email_error_at: nil,
          last_email_error_message: nil
        )

        Rails.logger.info("[EmailSendingJob] Successfully sent email for lead_id=#{lead_id} step_id=#{lead_run_step_id} send_number=#{send_number}")
      else
        # Legacy path: no step tracking, just update lead
        # (for backward compatibility with direct send endpoints)
        lead.update!(
          email_status: "sent",
          last_email_sent_at: Time.current,
          last_email_error_at: nil,
          last_email_error_message: nil,
          stage: "sent (#{send_number})"
        )
      end

    rescue TemporaryEmailError => e
      # RISK E: Use "retrying" not "failed" for temporary errors
      if step && output
        output_data = (output.output_data || {}).dup
        output_data.merge!(
          "email_status" => "retrying",
          "error" => e.message,
          "retryable" => true
        )
      output.update!(
        output_data: output_data
        # Keep status as "pending" - AgentOutput only allows pending/completed/failed
        # The "running" state is tracked in LeadRunStep
      )
      end

      lead.update!(
        email_status: "retrying", # NOT "failed"
        last_email_error_at: Time.current,
        last_email_error_message: e.message
      )

      Rails.logger.warn(
        "[EmailSendingJob] Retrying after temporary error for lead_id=#{lead_id} step_id=#{lead_run_step_id}: #{e.message}"
      )

      # Let ActiveJob's retry_on handle the retry
      raise

    rescue PermanentEmailError => e
      email_failed = true
      
      if step && output
        output_data = (output.output_data || {}).dup
        output_data.merge!(
          "email_status" => "failed",
          "failure_reason" => e.message,
          "error" => e.message
        )
        step.update!(status: "failed", step_finished_at: Time.current)
        output.update!(
          status: "failed",
          output_data: output_data,
          error_message: e.message.to_s.truncate(500)
        )

        # Update lead.stage to "send_failed"
        lead.update!(stage: "send_failed")
      end

      lead.update!(
        email_status: "failed",
        last_email_error_at: Time.current,
        last_email_error_message: e.message
      )

      Rails.logger.error(
        "[EmailSendingJob] Permanent email failure for lead_id=#{lead_id} step_id=#{lead_run_step_id}: #{e.message}"
      )

      # Let discard_on handle discarding
      raise
      
    rescue => e
      # Unexpected error - mark as failed
      email_failed = true
      Rails.logger.error(
        "[EmailSendingJob] Unexpected error for lead_id=#{lead_id} step_id=#{lead_run_step_id}: #{e.class} - #{e.message}"
      )
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise
      
    ensure
      # CRITICAL: Always finalize step/run if email was sent or failed
      # This ensures runs don't stay stuck in "running" state
      if step && run && (email_sent || email_failed)
        begin
          # Recompute run status to finalize it
          LeadRunExecutor.recompute_run_status!(run_id: run.id)
          Rails.logger.info("[EmailSendingJob] Finalized run_id=#{run.id} step_id=#{step.id} email_sent=#{email_sent} email_failed=#{email_failed}")
        rescue => e
          Rails.logger.error("[EmailSendingJob] Failed to finalize run_id=#{run.id}: #{e.class} - #{e.message}")
          # Don't raise - we've already handled the email outcome
      end
    end
  end
end
end
