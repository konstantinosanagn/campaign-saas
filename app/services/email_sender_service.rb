##
# EmailSenderService
#
# Service responsible for sending emails to leads that have completed
# the agent processing pipeline (SEARCH → WRITER → DESIGNER → CRITIQUE).
#
# Usage:
#   EmailSenderService.send_emails_for_campaign(campaign)
#   # Returns: { sent: 5, failed: 2, errors: [...] }
#
class EmailSenderService
  class << self
    ##
    # Sends emails to all ready leads in a campaign
    # A lead is considered "ready" if it has completed the CRITIQUE agent
    # (which runs after DESIGNER) and reached 'critiqued' or 'completed' stage
    #
    # @param campaign [Campaign] The campaign containing leads to send emails to
    # @return [Hash] Result with counts of sent/failed emails and any errors
    def send_emails_for_campaign(campaign)
      ready_leads = find_ready_leads(campaign)

      results = {
        sent: 0,
        failed: 0,
        errors: []
      }

      ready_leads.each do |lead|
        begin
          send_email_to_lead(lead)
          results[:sent] += 1
        rescue => e
          results[:failed] += 1
          results[:errors] << {
            lead_id: lead.id,
            lead_email: lead.email,
            error: e.message
          }
          Rails.logger.error("Failed to send email to lead #{lead.id}: #{e.message}")
        end
      end

      results
    end

    ##
    # Checks if a lead is ready to have its email sent
    # A lead is ready if:
    # 1. It has reached 'critiqued' or 'completed' stage (after CRITIQUE agent)
    # 2. It has a completed DESIGNER output (required, since DESIGNER runs before CRITIQUE)
    #
    # @param lead [Lead] The lead to check
    # @return [Boolean] True if lead is ready to send
    def lead_ready?(lead)
      # Must be at critiqued or completed stage (after CRITIQUE has run)
      return false unless lead.stage.in?(%w[critiqued completed])

      # Check for DESIGNER output (required, since DESIGNER runs before CRITIQUE now)
      designer_output = lead.agent_outputs.find_by(agent_name: "DESIGNER", status: "completed")
      if designer_output && designer_output.output_data["formatted_email"].present?
        return true
      end

      # Fallback to WRITER output only if DESIGNER is not available (for backward compatibility)
      writer_output = lead.agent_outputs.find_by(agent_name: "WRITER", status: "completed")
      if writer_output && writer_output.output_data["email"].present?
        Rails.logger.warn("Lead #{lead.id} ready to send but using WRITER output instead of DESIGNER")
        return true
      end

      false
    end

    private

    ##
    # Finds all leads in a campaign that are ready to send
    def find_ready_leads(campaign)
      campaign.leads.select { |lead| lead_ready?(lead) }
    end

    ##
    # Sends email to a single lead
    def send_email_to_lead(lead)
      # Get the email content (prefer DESIGNER formatted_email, fallback to WRITER email)
      # Since DESIGNER runs before CRITIQUE now, DESIGNER output should always be available
      designer_output = lead.agent_outputs.find_by(agent_name: "DESIGNER", status: "completed")
      writer_output = lead.agent_outputs.find_by(agent_name: "WRITER", status: "completed")

      email_content = nil
      if designer_output && designer_output.output_data["formatted_email"].present?
        email_content = designer_output.output_data["formatted_email"]
      elsif writer_output && writer_output.output_data["email"].present?
        email_content = writer_output.output_data["email"]
        Rails.logger.warn("Sending email to lead #{lead.id} using WRITER email (DESIGNER not available)")
      end

      raise "No email content found for lead #{lead.id}. DESIGNER or WRITER output required." if email_content.blank?

      from_email = lead.campaign.user&.email.presence || ApplicationMailer.default[:from]

      # Send email using CampaignMailer
      CampaignMailer.send_email(
        to: lead.email,
        recipient_name: lead.name,
        email_content: email_content,
        campaign_title: lead.campaign.title,
        from_email: from_email
      ).deliver_now
    end
  end
end
