module Api
  module V1
    class LeadsController < BaseController
      def index
        # Only return leads from campaigns belonging to the current user
        # Use preload instead of includes to avoid cartesian joins (row multiplication)
        leads = Lead.preload(:agent_outputs, campaign: :agent_configs, current_lead_run: :steps)
                    .joins(:campaign)
                    .where(campaigns: { user_id: current_user.id })

        # Prefetch active runs + steps in one pass for leads that may have nil pointers
        # (keeps payload correct without per-lead queries).
        active_runs =
          LeadRun
            .preload(:steps, campaign: :agent_configs)
            .where(lead_id: leads.map(&:id), status: LeadRun::ACTIVE_STATUSES)
            .order(created_at: :desc)

        active_runs_by_lead_id = {}
        active_runs.each do |run|
          active_runs_by_lead_id[run.lead_id] ||= run
        end

        render json: LeadSerializer.serialize_collection(leads, active_runs_by_lead_id: active_runs_by_lead_id)
      end



      def create
        # Verify the campaign belongs to current user before creating lead
        campaign = current_user.campaigns.find_by(id: lead_params[:campaign_id])
        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :unprocessable_entity
          return
        end

        lead = campaign.leads.build(lead_params.except(:campaign_id))
        if lead.save
          render json: LeadSerializer.serialize(lead), status: :created
        else
          render json: { errors: lead.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # Only allow updating leads from campaigns belonging to current user
        # Use includes to prevent N+1 queries
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])
        if lead && lead.update(lead_params.except(:campaign_id))
          render json: LeadSerializer.serialize(lead)
        else
          render json: { errors: lead ? lead.errors.full_messages : [ "Not found or unauthorized" ] }, status: :unprocessable_entity
        end
      end

      def destroy
        # Only allow deleting leads from campaigns belonging to current user
        # Use includes to prevent N+1 queries
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])
        if lead
          lead.destroy
          head :no_content
        else
          render json: { errors: [ "Not found or unauthorized" ] }, status: :not_found
        end
      end

      ##
      # POST /api/v1/leads/:id/run_agents
      # Runs all agents (SEARCH → WRITER → CRITIQUE → DESIGN) for a specific lead
      #
      # In production, this runs asynchronously via background job.
      # In development/test, this runs synchronously for easier debugging.
      # Use ?async=true to force async execution, ?async=false to force sync.
      def run_agents
        # Find lead and verify ownership
        # Use includes to prevent N+1 queries and eager load associations
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        # Reload lead to ensure fresh data and clear any stale agent_outputs cache
        # This is critical when leads are deleted and recreated
        lead.reload
        # Also clear the agent_outputs association cache to ensure fresh queries
        lead.association(:agent_outputs).reset

        # Get the campaign
        campaign = lead.campaign

        # Determine if we should run async or sync
        # Default: async in production, sync in development/test
        force_async = params[:async] == "true" || params[:async] == true
        force_sync = params[:async] == "false" || params[:async] == false

        use_async = if force_async
          true
        elsif force_sync
          false
        else
          # Default behavior: async in production, sync in development/test
          Rails.env.production?
        end

        # Get optional agent_name parameter
        agent_name = params[:agentName] || params[:agent_name]

        # Structured logging: initial request context
        log_context = {
          lead_id: lead.id,
          campaign_id: campaign.id,
          requested_agent_name: agent_name,
          use_async: use_async
        }

        begin
          # For SENDER requests, use ensure_sendable_run! to prevent 422 errors
          if agent_name.to_s == AgentConstants::AGENT_SENDER
            existing_active_run = lead.active_run
            run = LeadRuns.ensure_sendable_run!(lead: lead, requested_agent_name: agent_name)
            run_was_created = existing_active_run.nil? || existing_active_run.id != run.id
            log_context[:result] = run_was_created ? "created send-only run" : "reuse existing run"
          else
            # For other agents, use standard ensure_active_run!
            existing_active_run = lead.active_run
            run = lead.ensure_active_run!
            run_was_created = existing_active_run.nil? || existing_active_run.id != run.id
            log_context[:result] = run_was_created ? "created new run" : "reuse existing run"
          end
          
          # Log run creation/reuse
          log_context.merge!(
            active_run_id: run.id,
            run_was_created: run_was_created,
            run_status: run.status,
            plan_steps: (run.plan&.dig("steps") || []).map { |s| s["agent_name"] }
          )
          
          Rails.logger.info("[LeadsController#run_agents] run_creation lead_id=#{lead.id} run_id=#{run.id} run_was_created=#{run_was_created} plan_steps=#{log_context[:plan_steps].join(',')}")

          if AgentExecution.paused?
            log_context[:result] = "execution_paused"
            Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
            render json: LeadRuns.status_payload_for(lead).merge(status: "failed", error: "execution_paused"),
                   status: :service_unavailable
            return
          end

          # Policy 2: allow agentName if it becomes next after skipping disabled queued steps.
          if agent_name.present?
            LeadRun.transaction do
              locked_run = LeadRun.lock.find(run.id)
              # Apply the same "skip disabled queued steps" rule used by the executor.
              loop do
                step = locked_run.steps.where(status: "queued").order(:position).lock("FOR UPDATE").first
                break unless step

                enabled =
                  if step.agent_name.to_s == AgentConstants::AGENT_SENDER
                    cfg = AgentConfig.find_by(campaign_id: locked_run.campaign_id, agent_name: step.agent_name)
                    cfg.present? && cfg.enabled?
                  else
                    LeadAgentService::ConfigManager.get_agent_config(locked_run.campaign, step.agent_name).enabled?
                  end

                break if enabled

                meta = (step.meta || {}).dup
                meta["skip_reason"] = "agent_disabled"
                meta["skipped_at"] = Time.current.iso8601
                meta["skipped_agent_name"] = step.agent_name.to_s
                step.update!(status: "skipped", step_finished_at: Time.current, meta: meta)
                Rails.logger.info("[LeadsController#run_agents] run_id=#{locked_run.id} step_id=#{step.id} agent=#{step.agent_name} skipped (disabled)")
              end

              next_step = locked_run.steps.where(status: "queued").order(:position).first
              has_queued_sender = locked_run.steps.where(status: "queued", agent_name: AgentConstants::AGENT_SENDER).exists?
              
              log_context.merge!(
                next_step_agent_name: next_step&.agent_name,
                has_queued_sender_step: has_queued_sender
              )
              
              if next_step && next_step.agent_name.to_s != agent_name.to_s
                # Differentiate errors for SENDER requests
                if agent_name.to_s == AgentConstants::AGENT_SENDER
                  if has_queued_sender
                    # SENDER exists in plan but not next
                    log_context[:result] = "agent_not_next"
                    Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
                    render json: { status: "failed", error: "agent_not_next", nextAgent: next_step.agent_name }, status: :unprocessable_entity
                  else
                    # SENDER not in plan at all
                    log_context[:result] = "sender_not_planned"
                    Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
                    render json: { status: "failed", error: "sender_not_planned", reason: "not_in_plan", nextAgent: next_step.agent_name }, status: :unprocessable_entity
                  end
                else
                  log_context[:result] = "agent_not_next"
                  Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
                  render json: { status: "failed", error: "agent_not_next", nextAgent: next_step.agent_name }, status: :unprocessable_entity
                end
                raise ActiveRecord::Rollback
              end
            end

            return if performed?
          end

          if use_async
            job = AgentExecutionJob.perform_later({ lead_run_id: run.id, requested_agent_name: agent_name })
            log_context[:result] = "queued"
            log_context[:job_id] = job.job_id
            Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
            render json: LeadRuns.status_payload_for(lead, campaign: campaign, agent_configs: campaign.agent_configs).merge(status: "queued", jobId: job.job_id), status: :accepted
          else
            # For sync mode, validate API keys before running to provide immediate feedback.
            unless ApiKeyService.keys_available?(current_user)
              missing_keys = ApiKeyService.missing_keys(current_user)
              log_context[:result] = "missing_api_keys"
              log_context[:missing_keys] = missing_keys
              Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
              render json: {
                status: "failed",
                error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section."
              }, status: :unprocessable_entity
              return
            end

            LeadRunExecutor.run_next!(lead_run_id: run.id, requested_agent_name: agent_name)
            lead.reload
            # Reload campaign to get fresh agent_configs after potential changes
            campaign.reload
            log_context[:result] = "completed"
            Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
            render json: LeadRuns.status_payload_for(lead, campaign: campaign, agent_configs: campaign.agent_configs).merge(status: "completed"), status: :ok
          end
        rescue LeadRuns::RunInProgressError => e
          log_context[:result] = "rejected due to run_in_progress"
          log_context[:error] = e.message
          Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          render json: { 
            status: "failed", 
            error: "run_in_progress", 
            runId: e.run_id, 
            nextAgent: e.next_agent 
          }, status: :unprocessable_entity
        rescue LeadRuns::SenderNotPlannedError => e
          log_context[:result] = "rejected due to sender_not_planned"
          log_context[:error] = e.message
          Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          render json: { 
            status: "failed", 
            error: "sender_not_planned", 
            reason: e.reason 
          }, status: :unprocessable_entity
        rescue LeadRuns::SendingNotConfiguredError => e
          log_context[:result] = "rejected due to sending_not_configured"
          log_context[:error] = e.message
          Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          render json: { 
            status: "failed", 
            error: "sending_not_configured", 
            reasons: e.reasons 
          }, status: :unprocessable_entity
        rescue LeadRuns::AlreadySendingError => e
          log_context[:result] = "rejected due to already_sending"
          log_context[:error] = e.message
          Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          render json: { 
            status: "failed", 
            error: "already_sending", 
            stepId: e.step_id, 
            runId: e.run_id 
          }, status: :unprocessable_entity
        rescue LeadRunPlanner::PlannerError => e
          # Handle legacy PlannerError for backward compatibility
          error_response = { status: "failed", error: e.message }
          
          case e.message
          when "send_source_missing"
            error_response[:reason] = "no_design_or_writer_output"
            log_context[:result] = "rejected due to send_source_missing"
          else
            log_context[:result] = "planner_error"
          end
          
          log_context[:error] = e.message
          Rails.logger.info("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          render json: error_response, status: :unprocessable_entity
        rescue => e
          log_context[:result] = "error"
          log_context[:error] = e.message
          log_context[:error_class] = e.class.name
          Rails.logger.error("[LeadsController#run_agents] request_path_outcome #{log_context.to_json}")
          Rails.logger.error("LeadRun run_agents error: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
          render json: { status: "error", error: e.message }, status: :internal_server_error
        end
        return

        # Legacy state-machine (StageManager) removed.
      end

      ##
      # POST /api/v1/leads/:id/resume_run
      # Attempts to safely resume/repair an existing LeadRun.
      #
      # This is intentionally conservative:
      # - never enqueues inside DB transactions (service returns enqueue flag)
      # - no-op if already running (and not stale) or terminal
      def resume_run
        lead = Lead.includes(:campaign)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        run = lead.active_run
        unless run
          render json: { status: "noop", reason: "no_active_run" }, status: :ok
          return
        end

        if AgentExecution.paused?
          campaign = lead.campaign
          render json: LeadRuns.status_payload_for(lead, campaign: campaign, agent_configs: campaign.agent_configs).merge(status: "failed", error: "execution_paused"),
                 status: :service_unavailable
          return
        end

        result = LeadRuns::Resume.call(lead_run_id: run.id)

        job_id = nil
        if result[:enqueue]
          job = AgentExecutionJob.perform_later({ lead_run_id: run.id })
          job_id = job.job_id
        end

        lead.reload
        render json: LeadRuns.status_payload_for(lead).merge(
          resume: result,
          jobId: job_id
        ), status: :ok
      end

      ##
      # GET /api/v1/leads/:id/available_actions
      # Returns available actions (agents) that can be run for a specific lead
      # Based on current stage, critique score, and rewrite state
      def available_actions
        # Find lead and verify ownership
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        # Reload to ensure fresh data
        lead.reload
        lead.association(:agent_outputs).reset
        campaign = lead.campaign
        render json: LeadRuns.status_payload_for(lead, campaign: campaign, agent_configs: campaign.agent_configs), status: :ok
      end

      ##
      # GET /api/v1/leads/:id/agent_outputs
      # Returns all agent outputs for a specific lead
      def agent_outputs
        # Find lead and verify ownership
        # Use includes to prevent N+1 queries when loading agent_outputs
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        # Use already-loaded association if available, otherwise query with ordering
        # Note: Ruby sorting is efficient when association is preloaded (avoids redundant query).
        # If a lead has more than MAX_OUTPUTS_FOR_RUBY_SORT outputs, consider pagination.
        outputs = if lead.association(:agent_outputs).loaded?
          sorted = lead.agent_outputs.sort_by(&:created_at).reverse
          # Future guardrail: if outputs exceed threshold, log a warning for monitoring
          max_outputs_for_ruby_sort = 2000
          Rails.logger.warn("[LeadsController#agent_outputs] Lead #{lead.id} has #{sorted.length} outputs (threshold: #{max_outputs_for_ruby_sort}). Consider pagination.") if sorted.length > max_outputs_for_ruby_sort
          sorted
        else
          lead.agent_outputs.order(created_at: :desc)
        end

        render json: {
          leadId: lead.id,
          outputs: outputs.map { |output| AgentOutputSerializer.serialize(output) }
        }, status: :ok
      end

      # GET /api/v1/leads/:id/lead_runs
      # Debug endpoint to inspect LeadRuns + steps for a lead.
      def lead_runs
        lead = Lead.includes(:campaign)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        runs = lead.lead_runs.includes(:steps).order(created_at: :desc)

        render json: {
          lead_id: lead.id,
          runs: runs.map { |run|
            {
              id: run.id,
              status: run.status,
              rewrite_count: run.rewrite_count,
              min_score: run.min_score,
              max_rewrites: run.max_rewrites,
              started_at: run.started_at,
              finished_at: run.finished_at,
              steps: run.steps.map { |step|
                {
                  id: step.id,
                  position: step.position,
                  agent_name: step.agent_name,
                  status: step.status,
                  agent_output_id: step.agent_output_id,
                  meta: step.meta
                }
              }
            }
          }
        }, status: :ok
      end

      ##
      # POST /api/v1/leads/:id/send_email
      # Sends email to a single lead (routes through SENDER workflow for audit trail)
      def send_email
        # Find lead and verify ownership
        # Use includes to prevent N+1 queries and eager load agent_outputs
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        # Phase 6.1: Route through SENDER workflow to preserve audit trail
        begin
          # Use ensure_sendable_run! to create/reuse send-only run
          run = LeadRuns.ensure_sendable_run!(lead: lead, requested_agent_name: AgentConstants::AGENT_SENDER)
          
          # Always enqueue AgentExecutionJob for SENDER (explicit and consistent)
          # This ensures "queued" status actually means the job is enqueued
          job = AgentExecutionJob.perform_later(
            { lead_run_id: run.id, requested_agent_name: AgentConstants::AGENT_SENDER }
          )
          
          render json: {
            success: true,
            message: "Email sending queued",
            status: "queued",
            jobId: job.job_id
          }, status: :accepted
        rescue LeadRuns::RunInProgressError => e
          render json: { 
            success: false, 
            error: "run_in_progress", 
            runId: e.run_id, 
            nextAgent: e.next_agent 
          }, status: :unprocessable_entity
        rescue LeadRuns::SenderNotPlannedError => e
          render json: { 
            success: false, 
            error: "sender_not_planned", 
            reason: e.reason 
          }, status: :unprocessable_entity
        rescue LeadRuns::SendingNotConfiguredError => e
          render json: { 
            success: false, 
            error: "sending_not_configured", 
            reasons: e.reasons 
          }, status: :unprocessable_entity
        rescue LeadRuns::AlreadySendingError => e
          render json: { 
            success: false, 
            error: "already_sending", 
            stepId: e.step_id, 
            runId: e.run_id 
          }, status: :unprocessable_entity
        rescue LeadRunPlanner::PlannerError => e
          # Handle legacy PlannerError for backward compatibility
          error_response = { success: false, error: e.message }
          
          case e.message
          when "send_source_missing"
            error_response[:reason] = "no_design_or_writer_output"
          end
          
          render json: error_response, status: :unprocessable_entity
        rescue GmailAuthorizationError => e
          # Gmail token revoked/invalid
          render json: {
            success: false,
            error: e.message,
            requires_reconnect: true
          }, status: :unauthorized
        rescue => e
          Rails.logger.error("[LeadsController#send_email] Error: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
      end

      ##
      # PATCH /api/v1/leads/:id/update_agent_output
      # Updates a specific agent output (supports WRITER and SEARCH)
      def update_agent_output
        # Find lead and verify ownership
        # Use includes to prevent N+1 queries
        lead = Lead.includes(:campaign, :agent_outputs)
                   .joins(:campaign)
                   .where(campaigns: { user_id: current_user.id })
                   .find_by(id: params[:id])

        unless lead
          render json: { errors: [ "Lead not found or unauthorized" ] }, status: :not_found
          return
        end

        agent_name = params[:agentName] || params[:agent_name]

        unless agent_name
          render json: { errors: [ "Agent name is required" ] }, status: :unprocessable_entity
          return
        end

        # Only allow updating WRITER, SEARCH, and DESIGN
        unless agent_name.in?([ AgentConstants::AGENT_WRITER, AgentConstants::AGENT_SEARCH, AgentConstants::AGENT_DESIGN ])
          render json: { errors: [ "Only WRITER, SEARCH, and DESIGN agent outputs can be updated" ] }, status: :unprocessable_entity
          return
        end

        # Find the latest agent output (most recent)
        agent_output = lead.agent_outputs
                           .where(agent_name: agent_name)
                           .order(created_at: :desc)
                           .first

        unless agent_output
          render json: { errors: [ "Agent output not found" ] }, status: :not_found
          return
        end

        # Handle different agent types
        if agent_name == AgentConstants::AGENT_WRITER
          # Get the new email content from params
          new_email = params[:content] || params[:email]

          unless new_email
            render json: { errors: [ "Email content is required" ] }, status: :unprocessable_entity
            return
          end

          # Update the output data
          updated_data = agent_output.output_data.merge(email: new_email)
          agent_output.update!(output_data: updated_data)
        elsif agent_name == AgentConstants::AGENT_DESIGN
          # Get the new formatted email content from params
          new_email = params[:content] || params[:email] || params[:formatted_email]

          unless new_email
            render json: { errors: [ "Email content is required" ] }, status: :unprocessable_entity
            return
          end

          # Update the output data
          updated_data = agent_output.output_data.merge(
            email: new_email,
            formatted_email: new_email
          )
          agent_output.update!(output_data: updated_data)
        elsif agent_name == AgentConstants::AGENT_SEARCH
          # Get the updated data from params
          updated_data_param = params[:updatedData] || params[:updated_data]

          unless updated_data_param
            render json: { errors: [ "Updated data is required for SEARCH agent" ] }, status: :unprocessable_entity
            return
          end

          # Update the output data
          agent_output.update!(output_data: updated_data_param)
        end

        render json: AgentOutputSerializer.serialize(agent_output), status: :ok
      end

      ##
      # POST /api/v1/leads/batch_run_agents
      # Runs agents for multiple leads in parallel batches
      #
      # Request body:
      #   {
      #     leadIds: [1, 2, 3],
      #     campaignId: 1,
      #     batchSize: 10 (optional)
      #   }
      #
      # Returns:
      #   {
      #     success: true,
      #     total: 10,
      #     queued: 8,
      #     failed: 2,
      #     results: [...]
      #   }
      def batch_run_agents
        campaign_id = params[:campaignId] || params[:campaign_id]
        lead_ids = params[:leadIds]

        # Case 1: leadIds is missing entirely
        if lead_ids.nil?
          return render json: { errors: [ "leadIds is required" ] },
                        status: :unprocessable_entity
        end

        # Case 2: leadIds present but empty array: []
        if lead_ids.is_a?(Array) && lead_ids.empty?
          return render json: { errors: [ "leadIds must be a non-empty array" ] },
                        status: :unprocessable_entity
        end

        batch_size = (params[:batchSize] || params[:batch_size] || BatchLeadProcessingService.recommended_batch_size).to_i

        if campaign_id.nil?
          return render json: { errors: [ "campaignId is required" ] },
                        status: :unprocessable_entity
        end

        # Verify campaign ownership and get campaign
        campaign = current_user.campaigns.find_by(id: campaign_id)
        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        # Filter leads by campaign to prevent cross-campaign access
        leads = campaign.leads.where(id: lead_ids)

        begin
          if AgentExecution.paused?
            planned = []
            failed = []

            leads.find_each do |lead|
              begin
                run = lead.ensure_active_run!
                planned << { lead_id: lead.id, lead_run_id: run.id }
              rescue => e
                failed << { lead_id: lead.id, error: e.message }
              end
            end

            render json: {
              success: false,
              error: "execution_paused",
              errors: [ "execution_paused" ],
              total: leads.count,
              queued: 0,
              failed: failed.count,
              planned: planned,
              failedLeads: failed
            }, status: :service_unavailable
            return
          end

          # Validate API keys before processing (to avoid queuing jobs that will fail).
          unless ApiKeyService.keys_available?(current_user)
            missing_keys = ApiKeyService.missing_keys(current_user)
            render json: {
              success: false,
              error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section.",
              total: leads.count,
              queued: 0,
              failed: 0
            }, status: :unprocessable_entity
            return
          end

          # Process leads in batches (use filtered lead IDs)
          filtered_lead_ids = leads.pluck(:id)
          result = BatchLeadProcessingService.process_leads(
            filtered_lead_ids,
            campaign,
            current_user,
            batch_size: batch_size
          )

          if result[:error]
            render json: {
              success: false,
              error: result[:error],
              errors: [ result[:error] ],
              total: result[:total],
              queued: result[:queued_count] || 0,
              failed: result[:failed_count] || 0
            }, status: :unprocessable_entity
          else
            render json: {
              success: true,
              total: result[:total],
              queued: result[:queued_count],
              failed: result[:failed_count],
              queuedLeads: result[:queued],
              failedLeads: result[:failed]
            }, status: :accepted
          end
        rescue => e
          Rails.logger.error("BatchLeadProcessingService error: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render json: {
            success: false,
            error: "Failed to process batch: #{e.message}",
            total: leads.count,
            queued: 0,
            failed: 0
          }, status: :internal_server_error
        end
      end

      private

      def lead_params
        # Convert camelCase to snake_case for database
        params_hash = params.require(:lead).permit(:name, :email, :title, :company, :website, :campaignId, :stage, :quality).to_h.with_indifferent_access
        params_hash[:campaign_id] = params_hash.delete(:campaignId) if params_hash[:campaignId]
        params_hash
      end
    end
  end
end
