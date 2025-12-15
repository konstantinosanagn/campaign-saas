##
# AgentExecutionJob
#
# Background job for executing AI agents on leads. This prevents blocking
# the HTTP request while agents run, which can take several seconds.
#
# Usage:
#   AgentExecutionJob.perform_later(lead_id, campaign_id, user_id)
#   AgentExecutionJob.perform_later(lead_id, campaign_id, user_id, agent_name)  # Manual execution
#
class AgentExecutionJob < ApplicationJob
  queue_as :default

  # Retry configuration
  # Use exponential backoff: 2^attempt seconds (2s, 4s, 8s)
  retry_on StandardError, wait: ->(attempt) { 2 ** attempt }, attempts: 3
  retry_on AgentExecution::ExecutionPausedError, wait: 5.minutes, attempts: 100

  # Don't retry on these errors
  discard_on ArgumentError # Missing API keys, invalid parameters

  ##
  # Executes agents for a lead in the background
  #
  # Legacy usage:
  #   perform(lead_id, campaign_id, user_id, agent_name = nil)
  #
  # LeadRun usage (new):
  #   perform({ lead_run_id: 123 })
  def perform(*args)
    if AgentExecution.paused?
      Rails.logger.info("[AgentExecutionJob] execution paused; job will retry later")
      raise AgentExecution::ExecutionPausedError, "execution_paused"
    end

    unless args.length == 1 && args.first.is_a?(Hash)
      raise ArgumentError, "AgentExecutionJob legacy signature removed; pass { lead_run_id: ... }"
    end

    payload = args.first.with_indifferent_access
    lead_run_id = payload[:lead_run_id]
    raise ArgumentError, "lead_run_id is required" if lead_run_id.blank?

    requested_agent_name = payload[:requested_agent_name] || payload[:agent_name]
    perform_lead_run!(lead_run_id, requested_agent_name: requested_agent_name)
  end

  private

  def perform_lead_run!(lead_run_id, requested_agent_name: nil)
    run = LeadRun.find_by(id: lead_run_id)
    return unless run

    LeadRunExecutor.run_next!(lead_run_id: run.id, requested_agent_name: requested_agent_name)
  end
end
