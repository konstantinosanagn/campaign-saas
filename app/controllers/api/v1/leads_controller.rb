module Api
  module V1
    class LeadsController < BaseController
      def index
        # Only return leads from campaigns belonging to the current user
        # Use includes to prevent N+1 queries when accessing associations
        render json: Lead.includes(:campaign, :agent_outputs)
                         .joins(:campaign)
                         .where(campaigns: { user_id: current_user.id })
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
          render json: lead, status: :created
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
          render json: lead
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
          # Enqueue background job
          begin
            job = AgentExecutionJob.perform_later(lead.id, campaign.id, current_user.id)

            render json: {
              status: "queued",
              message: "Agent execution queued successfully",
              job_id: job.job_id,
              lead: lead
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
            # Run agents using LeadAgentService
            result = LeadAgentService.run_agents_for_lead(lead, campaign, current_user)

            # Check for service-level errors
            if result[:status] == "failed" && result[:error]
              render json: {
                status: result[:status],
                error: result[:error],
                lead: lead
              }, status: :unprocessable_entity
              return
            end

            # Return success response with results
            render json: {
              status: result[:status],
              outputs: result[:outputs],
              lead: lead,
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

        # Get all agent outputs for this lead
        outputs = lead.agent_outputs.map do |output|
          {
            agentName: output.agent_name,
            status: output.status,
            outputData: output.output_data,
            errorMessage: output.error_message,
            createdAt: output.created_at,
            updatedAt: output.updated_at
          }
        end

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

        # Find the agent output
        agent_output = lead.agent_outputs.find_by(agent_name: agent_name)

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

        render json: {
          agentName: agent_output.agent_name,
          status: agent_output.status,
          outputData: agent_output.output_data,
          updatedAt: agent_output.updated_at
        }, status: :ok
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
