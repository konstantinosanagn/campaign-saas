##
# AgentExecutionJob
#
# Background job for executing AI agents on leads. This prevents blocking
# the HTTP request while agents run, which can take several seconds.
#
# Usage:
#   AgentExecutionJob.perform_later(lead_id, campaign_id, user_id)
#
class AgentExecutionJob < ApplicationJob
  queue_as :default

  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Don't retry on these errors
  discard_on ArgumentError # Missing API keys, invalid parameters

  ##
  # Executes agents for a lead in the background
  #
  # @param lead_id [Integer] The ID of the lead to process
  # @param campaign_id [Integer] The ID of the campaign containing agent configs
  # @param user_id [Integer] The ID of the user (for API keys)
  def perform(lead_id, campaign_id, user_id)
    # Reload records to ensure we have fresh data
    lead = Lead.find_by(id: lead_id)
    campaign = Campaign.find_by(id: campaign_id)
    user = User.find_by(id: user_id)

    # Verify ownership (security check)
    unless campaign && campaign.user_id == user_id
      Rails.logger.error("AgentExecutionJob: Unauthorized access attempt - campaign #{campaign_id} does not belong to user #{user_id}")
      return
    end

    unless lead && lead.campaign_id == campaign.id
      Rails.logger.error("AgentExecutionJob: Lead #{lead_id} does not belong to campaign #{campaign_id}")
      return
    end

    # Reload user to ensure we have fresh data
    user = User.find(user_id)

    # Check API keys before running agents - raise ArgumentError if missing
    # This will cause the job to be discarded (discard_on ArgumentError)
    ApiKeyService.get_gemini_api_key(user)
    ApiKeyService.get_tavily_api_key(user)

    # Execute agents
    begin
      result = LeadAgentService.run_agents_for_lead(lead, campaign, user)

      # Log the result
      if result[:status] == "failed"
        Rails.logger.warn("AgentExecutionJob: Agent execution failed for lead #{lead_id}: #{result[:error]}")
      else
        Rails.logger.info("AgentExecutionJob: Successfully executed agents for lead #{lead_id}. Completed: #{result[:completed_agents]}, Failed: #{result[:failed_agents]}")
      end
    rescue => e
      Rails.logger.error("AgentExecutionJob: Unexpected error processing lead #{lead_id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise # Re-raise to trigger retry mechanism
    end
  end
end
