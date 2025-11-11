##
# EmailSenderService
#
# Service responsible for sending emails to leads that have completed
# the agent processing pipeline (SEARCH → WRITER → CRITIQUE → DESIGN).
#
# Usage:
#   EmailSenderService.send_emails_for_campaign(campaign)
#   # Returns: { sent: 5, failed: 2, errors: [...] }
#
class EmailSenderService
  include AgentConstants
  class << self
    ##
    # Sends emails to all ready leads in a campaign
    # A lead is considered "ready" if it has completed the DESIGN agent
    # (or WRITER agent if DESIGN is disabled) and reached 'designed' or 'completed' stage
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
    # 1. It has reached 'designed' or 'completed' stage
    # 2. It has a completed DESIGN output (preferred) or WRITER output (fallback)
    #
    # @param lead [Lead] The lead to check
    # @return [Boolean] True if lead is ready to send
    def lead_ready?(lead)
      # Must be at designed or completed stage
      return false unless lead.stage.in?([STAGE_DESIGNED, STAGE_COMPLETED])

      # Check for DESIGN output first (preferred)
      design_output = lead.agent_outputs.find_by(agent_name: AGENT_DESIGN, status: STATUS_COMPLETED)
      if design_output && design_output.output_data["formatted_email"].present?
        return true
      end

      # Fallback to WRITER output if DESIGN is not available
      writer_output = lead.agent_outputs.find_by(agent_name: AGENT_WRITER, status: STATUS_COMPLETED)
      if writer_output && writer_output.output_data["email"].present?
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
      # Get the email content (prefer DESIGN formatted_email, fallback to WRITER email)
      design_output = lead.agent_outputs.find_by(agent_name: AGENT_DESIGN, status: STATUS_COMPLETED)
      writer_output = lead.agent_outputs.find_by(agent_name: AGENT_WRITER, status: STATUS_COMPLETED)

      email_content = nil
      if design_output && design_output.output_data["formatted_email"].present?
        email_content = design_output.output_data["formatted_email"]
      elsif writer_output && writer_output.output_data["email"].present?
        email_content = writer_output.output_data["email"]
      end

      raise "No email content found for lead #{lead.id}" if email_content.blank?

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
