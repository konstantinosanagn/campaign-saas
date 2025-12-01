##
# BatchLeadProcessingService
#
# Service for processing multiple leads in parallel batches to improve throughput
# and scalability. This allows running agents for multiple leads concurrently instead
# of sequentially.
#
# Usage:
#   result = BatchLeadProcessingService.process_leads(lead_ids, campaign, user)
#   # Returns: { completed: [...], failed: [...], total: 10, completed_count: 8, failed_count: 2 }
#
# Features:
# - Processes leads in configurable batch sizes
# - Parallel execution using background jobs
# - Progress tracking and error handling
# - Prevents overwhelming the system with too many concurrent jobs
#
class BatchLeadProcessingService
  # Maximum number of leads to process in parallel (to prevent system overload)
  MAX_CONCURRENT_JOBS = 25
  DEFAULT_PROD_BATCH_SIZE = 25
  DEFAULT_DEV_BATCH_SIZE = 10

  class << self
    ##
    # Processes multiple leads in batches using background jobs
    #
    # @param lead_ids [Array<Integer>] Array of lead IDs to process
    # @param campaign [Campaign] The campaign containing the leads
    # @param user [User] The user who owns the campaign
    # @param batch_size [Integer] Number of leads to process per batch (default: 10)
    # @return [Hash] Result with completed, failed, and summary statistics
    def process_leads(lead_ids, campaign, user, batch_size: DEFAULT_PROD_BATCH_SIZE)
      # Validate inputs
      unless campaign && campaign.user_id == user.id
        return {
          error: "Campaign not found or unauthorized",
          completed: [],
          failed: [],
          queued: [],
          total: 0,
          completed_count: 0,
          failed_count: 0,
          queued_count: 0
        }
      end

      # Filter to only leads that belong to this campaign
      valid_leads = Lead.where(id: lead_ids, campaign_id: campaign.id)
      valid_lead_ids = valid_leads.pluck(:id)

      if valid_lead_ids.empty?
        return {
          error: "No valid leads found",
          completed: [],
          failed: [],
          queued: [],
          total: 0,
          completed_count: 0,
          failed_count: 0,
          queued_count: 0
        }
      end

      # Process in batches to avoid overwhelming the job queue
      results = {
        completed: [],
        failed: [],
        queued: [],
        total: valid_lead_ids.length,
        completed_count: 0,
        failed_count: 0,
        queued_count: 0
      }

      # Split into batches
      valid_lead_ids.each_slice(batch_size) do |batch_lead_ids|
        batch_lead_ids.each do |lead_id|
          begin
            # Enqueue background job for each lead
            job = AgentExecutionJob.perform_later(lead_id, campaign.id, user.id)
            results[:queued] << { lead_id: lead_id, job_id: job.job_id }
            results[:queued_count] += 1
          rescue => e
            Rails.logger.error("BatchLeadProcessingService: Failed to enqueue job for lead #{lead_id}: #{e.message}")
            results[:failed] << {
              lead_id: lead_id,
              error: e.message
            }
            results[:failed_count] += 1
          end
        end

        # Add small delay between batches to prevent queue flooding
        sleep(0.1) if valid_lead_ids.length > batch_size
      end

      results
    end

    ##
    # Processes multiple leads synchronously in batches (for testing/development)
    # WARNING: This blocks execution - use process_leads for production
    #
    # @param lead_ids [Array<Integer>] Array of lead IDs to process
    # @param campaign [Campaign] The campaign containing the leads
    # @param user [User] The user who owns the campaign
    # @param batch_size [Integer] Number of leads to process per batch
    # @return [Hash] Result with completed and failed leads
    def process_leads_sync(lead_ids, campaign, user, batch_size: DEFAULT_PROD_BATCH_SIZE)
      # Validate inputs
      unless campaign && campaign.user_id == user.id
        return {
          error: "Campaign not found or unauthorized",
          completed: [],
          failed: [],
          total: 0,
          completed_count: 0,
          failed_count: 0
        }
      end

      # Filter to only leads that belong to this campaign
      valid_leads = Lead.includes(:agent_outputs)
                        .where(id: lead_ids, campaign_id: campaign.id)
                        .order(:id)

      results = {
        completed: [],
        failed: [],
        total: valid_leads.length,
        completed_count: 0,
        failed_count: 0
      }

      # Process in batches
      valid_leads.in_batches(of: batch_size) do |batch|
        batch.each do |lead|
          begin
            result = LeadAgentService.run_agents_for_lead(lead, campaign, user)
            if result[:status] == "completed"
              results[:completed] << {
                lead_id: lead.id,
                status: result[:status],
                completed_agents: result[:completed_agents]
              }
              results[:completed_count] += 1
            else
              results[:failed] << {
                lead_id: lead.id,
                status: result[:status],
                error: result[:error],
                failed_agents: result[:failed_agents]
              }
              results[:failed_count] += 1
            end
          rescue => e
            Rails.logger.error("BatchLeadProcessingService: Failed to process lead #{lead.id}: #{e.message}")
            results[:failed] << {
              lead_id: lead.id,
              error: e.message
            }
            results[:failed_count] += 1
          end
        end
      end

      results
    end

    ##
    # Gets the recommended batch size based on system configuration
    #
    # @return [Integer] Recommended batch size
    def recommended_batch_size
      env_size = ENV["BATCH_SIZE"]&.to_i

      size =
        if env_size && env_size.positive?
          env_size
        else
          default_size_for_env
        end

      [ size, MAX_CONCURRENT_JOBS ].min
    end

    ##
    # Gets the default batch size for the current environment
    #
    # @return [Integer] Default batch size for current environment
    def default_size_for_env
      if Rails.env.production?
        DEFAULT_PROD_BATCH_SIZE
      else
        DEFAULT_DEV_BATCH_SIZE
      end
    end
  end
end
