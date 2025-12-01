##
# EmailSendingJob
#
# Background job for sending emails to leads. This prevents blocking
# the HTTP request while emails are sent, which is critical for batch operations.
#
# Usage:
#   EmailSendingJob.perform_later(lead_id)
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
  def perform(lead_id)
    lead = Lead.find_by(id: lead_id)

    unless lead
      Rails.logger.warn("[EmailSendingJob] Lead #{lead_id} not found; skipping")
      return
    end

    # Allow resending - the service will handle idempotency if needed
    # For demo/testing purposes, we allow resending emails
    EmailSenderService.new(lead).send_email!

  rescue TemporaryEmailError => e
    # specs expect:
    # - email_status == 'failed'
    # - last_email_error_message includes "Network timeout"
    lead.update!(
      email_status: "failed",
      last_email_error_at: Time.current,
      last_email_error_message: e.message
    )

    # spec checks for /Retrying after temporary error/
    Rails.logger.warn(
      "Retrying after temporary error for lead_id=#{lead_id}: #{e.message}"
    )

    # Let ActiveJob's retry_on handle the retry
    raise

  rescue PermanentEmailError => e
    # specs expect:
    # - email_status == 'failed'
    # - last_email_error_message includes "Authentication failed"
    lead.update!(
      email_status: "failed",
      last_email_error_at: Time.current,
      last_email_error_message: e.message
    )

    # spec checks for /Permanent email failure for lead_id=.../
    Rails.logger.error(
      "Permanent email failure for lead_id=#{lead_id}: #{e.message}"
    )

    # Let discard_on handle discarding
    raise
  end
end
