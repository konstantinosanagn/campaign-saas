module Api
  module V1
    class AgentConfigsController < BaseController
      ##
      # GET /api/v1/campaigns/:campaign_id/agent_configs
      # Returns all agent configs for a campaign
      def index
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])
        
        unless campaign
          render json: { errors: ['Campaign not found or unauthorized'] }, status: :not_found
          return
        end
        
        configs = campaign.agent_configs.map do |config|
          {
            id: config.id,
            agentName: config.agent_name,
            enabled: config.enabled,
            settings: config.settings,
            createdAt: config.created_at,
            updatedAt: config.updated_at
          }
        end
        
        render json: {
          campaignId: campaign.id,
          configs: configs
        }, status: :ok
      end

      ##
      # GET /api/v1/campaigns/:campaign_id/agent_configs/:id
      # Returns a specific agent config
      def show
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])
        
        unless campaign
          render json: { errors: ['Campaign not found or unauthorized'] }, status: :not_found
          return
        end
        
        config = campaign.agent_configs.find_by(id: params[:id])
        
        unless config
          render json: { errors: ['Agent config not found'] }, status: :not_found
          return
        end
        
        render json: {
          id: config.id,
          agentName: config.agent_name,
          enabled: config.enabled,
          settings: config.settings,
          createdAt: config.created_at,
          updatedAt: config.updated_at
        }, status: :ok
      end

      ##
      # POST /api/v1/campaigns/:campaign_id/agent_configs
      # Creates a new agent config
      def create
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])
        
        unless campaign
          render json: { errors: ['Campaign not found or unauthorized'] }, status: :not_found
          return
        end
        
        # Validate agent name
        unless AgentConfig::VALID_AGENT_NAMES.include?(agent_config_params[:agent_name])
          render json: { errors: ['Invalid agent name. Must be one of: SEARCH, WRITER, CRITIQUE'] }, status: :unprocessable_entity
          return
        end
        
        # Check if config already exists
        existing_config = campaign.agent_configs.find_by(agent_name: agent_config_params[:agent_name])
        if existing_config
          render json: { errors: ['Agent config already exists for this campaign'] }, status: :unprocessable_entity
          return
        end
        
        config = campaign.agent_configs.build(
          agent_name: agent_config_params[:agent_name],
          enabled: agent_config_params[:enabled] != false, # Default to true
          settings: agent_config_params[:settings] || {}
        )
        
        if config.save
          render json: {
            id: config.id,
            agentName: config.agent_name,
            enabled: config.enabled,
            settings: config.settings,
            createdAt: config.created_at,
            updatedAt: config.updated_at
          }, status: :created
        else
          render json: { errors: config.errors.full_messages }, status: :unprocessable_entity
        end
      end

      ##
      # PATCH/PUT /api/v1/campaigns/:campaign_id/agent_configs/:id
      # Updates an existing agent config
      def update
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])
        
        unless campaign
          render json: { errors: ['Campaign not found or unauthorized'] }, status: :not_found
          return
        end
        
        config = campaign.agent_configs.find_by(id: params[:id])
        
        unless config
          render json: { errors: ['Agent config not found'] }, status: :not_found
          return
        end
        
        # Only allow updating enabled status and settings
        # Agent name cannot be changed
        update_params = agent_config_params.except(:agent_name)
        
        if config.update(update_params)
          render json: {
            id: config.id,
            agentName: config.agent_name,
            enabled: config.enabled,
            settings: config.settings,
            createdAt: config.created_at,
            updatedAt: config.updated_at
          }, status: :ok
        else
          render json: { errors: config.errors.full_messages }, status: :unprocessable_entity
        end
      end

      ##
      # DELETE /api/v1/campaigns/:campaign_id/agent_configs/:id
      # Deletes an agent config
      def destroy
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])
        
        unless campaign
          render json: { errors: ['Campaign not found or unauthorized'] }, status: :not_found
          return
        end
        
        config = campaign.agent_configs.find_by(id: params[:id])
        
        if config
          config.destroy
          head :no_content
        else
          render json: { errors: ['Agent config not found'] }, status: :not_found
        end
      end

      private

      def agent_config_params
        params.require(:agent_config).permit(:agent_name, :enabled, settings: {})
      rescue ActionController::ParameterMissing
        # Allow empty params for flexibility
        params.permit(:agent_name, :enabled, settings: {}).with_indifferent_access
      end
    end
  end
end

