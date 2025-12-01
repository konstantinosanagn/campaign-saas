module Api
  module V1
    class LeadsController < BaseController
      def index
        # Only return leads from campaigns belonging to the current user
        # Use includes to prevent N+1 queries when accessing associations
        leads = Lead.includes(:campaign, :agent_outputs)
                    .joins(:campaign)
                    .where(campaigns: { user_id: current_user.id })
        render json: LeadSerializer.serialize_collection(leads)
      end



      def create
        # Verify the campaign belongs to current user before creating lead
        Rails.logger.info "🧩 Incoming params: #{params.inspect}"
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

        if use_async
          # For async mode, allow job to be queued - the job will handle missing API keys
          # and be discarded gracefully (discard_on ArgumentError)
        else
          # For sync mode, validate API keys before running to provide immediate feedback
          unless ApiKeyService.keys_available?(current_user)
            missing_keys = ApiKeyService.missing_keys(current_user)
            render json: {
              status: "failed",
              error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section.",
              lead: LeadSerializer.serialize(lead)
            }, status: :unprocessable_entity
            return
          end
        end

        # Get optional agent_name parameter
        agent_name = params[:agentName] || params[:agent_name]

        if use_async
          # Enqueue background job with agent_name parameter
          begin
            job = AgentExecutionJob.perform_later(lead.id, campaign.id, current_user.id, agent_name)

          render json: {
            status: "queued",
            message: "Agent execution queued successfully",
            jobId: job.job_id,
            lead: LeadSerializer.serialize(lead)
          }, status: :accepted
          rescue => e
            Rails.logger.error("Failed to enqueue AgentExecutionJob: #{e.message}")
            render json: {
              status: "error",
              error: "Failed to queue agent execution: #{e.message}"
            }, status: :internal_server_error
          end
        else
          # Run synchronously (for development/test or when explicitly requested)
          begin
            # Run agents using LeadAgentService, passing optional agent_name
            result = LeadAgentService.run_agents_for_lead(lead, campaign, current_user, agent_name: agent_name)

            # Check for service-level errors
            if result[:status] == "failed" && result[:error]
              render json: {
                status: result[:status],
                error: result[:error],
                lead: LeadSerializer.serialize(lead)
              }, status: :unprocessable_entity
              return
            end

            # Return success response with results
            render json: {
              status: result[:status],
              outputs: result[:outputs],
              lead: LeadSerializer.serialize(lead),
              completedAgents: result[:completed_agents],
              failedAgents: result[:failed_agents]
            }, status: :ok

          rescue => e
            # Handle any unexpected errors
            render json: {
              status: "error",
              error: e.message
            }, status: :internal_server_error
          end
        end
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

        # Determine available actions using StageManager
        actions = LeadAgentService::StageManager.determine_available_actions(lead)

        render json: {
          leadId: lead.id,
          availableActions: actions
        }, status: :ok
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

        # Get all agent outputs for this lead, ordered by created_at DESC (newest first)
        outputs = lead.agent_outputs
                     .order(created_at: :desc)
                     .map { |output| AgentOutputSerializer.serialize(output) }

        render json: {
          leadId: lead.id,
          outputs: outputs
        }, status: :ok
      end

      ##
      # POST /api/v1/leads/:id/send_email
      # Sends email to a single lead
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

        begin
          result = EmailSenderService.send_email_for_lead(lead)

          if result[:success]
            render json: {
              success: true,
              message: result[:message]
            }, status: :ok
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        rescue GmailAuthorizationError => e
          # Gmail token revoked/invalid - credentials already cleared by EmailSenderService
          render json: {
            success: false,
            error: e.message,
            requires_reconnect: true
          }, status: :unauthorized
        rescue => e
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
        lead_ids = params[:leadIds] || params[:lead_ids] || []
        campaign_id = params[:campaignId] || params[:campaign_id]
        batch_size = (params[:batchSize] || params[:batch_size] || BatchLeadProcessingService.recommended_batch_size).to_i

        unless campaign_id
          render json: { errors: [ "campaignId is required" ] }, status: :unprocessable_entity
          return
        end

        unless lead_ids.is_a?(Array) && lead_ids.any?
          render json: { errors: [ "leadIds must be a non-empty array" ] }, status: :unprocessable_entity
          return
        end

        # Verify campaign ownership
        campaign = current_user.campaigns.find_by(id: campaign_id)
        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        # Validate API keys before processing (to avoid queuing jobs that will fail)
        unless ApiKeyService.keys_available?(current_user)
          missing_keys = ApiKeyService.missing_keys(current_user)
          render json: {
            success: false,
            error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section.",
            total: lead_ids.length,
            queued: 0,
            failed: 0
          }, status: :unprocessable_entity
          return
        end

        begin
          # Process leads in batches
          result = BatchLeadProcessingService.process_leads(
            lead_ids,
            campaign,
            current_user,
            batch_size: batch_size
          )

          if result[:error]
            render json: {
              success: false,
              error: result[:error],
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
            total: lead_ids.length,
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
