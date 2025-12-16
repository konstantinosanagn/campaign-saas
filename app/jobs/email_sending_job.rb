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
  # @param sender_step_id [Integer, nil] Optional SENDER step ID for tracking
  def perform(lead_id, sender_step_id = nil)
    lead = Lead.find_by(id: lead_id)
    unless lead
      Rails.logger.warn("[EmailSendingJob] Lead #{lead_id} not found; skipping")
      return
    end

    service = EmailSenderService.new(lead)

    # (Optional) log provider (this line caused failures when method was private)
    provider = service.current_provider
    Rails.logger.info("EmailSendingJob: provider=#{provider} lead_id=#{lead.id}")

    # allow resend if already sent (your specs mention this behavior)
    if lead.email_status == "sent"
      Rails.logger.info("EmailSendingJob: lead #{lead.id} already sent; resetting status to resend")
      lead.update!(email_status: "sending")
    else
      lead.update!(email_status: "sending")
    end

    # call the sender
    service.send_email!

    lead.update!(email_status: "sent")
    # ✅ if sender_step_id present, mark step completed, update agent output, etc.
    mark_sender_step_success!(lead, sender_step_id)

  rescue TemporaryEmailError => e
    lead.update!(email_status: "retrying")
    mark_sender_step_retrying!(lead, sender_step_id, e)
    Rails.logger.error("EmailSendingJob temporary error: #{e.class}: #{e.message}")
    raise # ✅ REQUIRED for your specs

  rescue PermanentEmailError => e
    lead.update!(email_status: "failed")
    mark_sender_step_failed!(lead, sender_step_id, e)
    Rails.logger.error("EmailSendingJob permanent error: #{e.class}: #{e.message}")
    raise # ✅ REQUIRED for your specs
  end

  private

  def mark_sender_step_success!(lead, sender_step_id)
    return if sender_step_id.nil?
    step = LeadRunStep.find(sender_step_id)
    step.update!(status: "completed")
    # update/create AgentOutput for this step if you track it
    output = AgentOutput.find_by(lead_run_step_id: sender_step_id)
    if output
      output_data = (output.output_data || {}).dup
      output_data["email_status"] = "sent"
      output.update!(status: "completed", output_data: output_data)
    end
  end

  def mark_sender_step_retrying!(lead, sender_step_id, err)
    return if sender_step_id.nil?
    step = LeadRunStep.find(sender_step_id)
    # spec says: keep step running with email_status=retrying
    step.update!(status: "running")
    # update AgentOutput.output_data["email_status"]="retrying"
    output = AgentOutput.find_by(lead_run_step_id: sender_step_id)
    if output
      output_data = (output.output_data || {}).dup
      output_data["email_status"] = "retrying"
      output.update!(output_data: output_data)
    end
  end

  def mark_sender_step_failed!(lead, sender_step_id, err)
    return if sender_step_id.nil?
    step = LeadRunStep.find(sender_step_id)
    step.update!(status: "failed")
    # also set lead stage to send_failed if your app has that convention
    lead.update!(stage: "send_failed")
    output = AgentOutput.find_by(lead_run_step_id: sender_step_id)
    if output
      output_data = (output.output_data || {}).dup
      output_data["email_status"] = "failed"
      output_data["error"] = err.message
      output.update!(status: "failed", output_data: output_data, error_message: err.message.to_s.truncate(500))
    end
  end
end
