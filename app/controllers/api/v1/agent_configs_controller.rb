module Api
  module V1
    class AgentConfigsController < BaseController
      ##
      # GET /api/v1/campaigns/:campaign_id/agent_configs
      # Returns all agent configs for a campaign
      def index
        campaign = current_user.campaigns.find_by(id: params[:campaign_id])

        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
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
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        config = campaign.agent_configs.find_by(id: params[:id])

        unless config
          render json: { errors: [ "Agent config not found" ] }, status: :not_found
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
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        # Normalize agent_name (handle both camelCase and snake_case)
        agent_name = agent_config_params[:agent_name] || agent_config_params[:agentName]

        # Validate agent name
        unless AgentConfig::VALID_AGENT_NAMES.include?(agent_name)
          render json: { errors: [ "Invalid agent name. Must be one of: SEARCH, WRITER, DESIGNER, CRITIQUE" ] }, status: :unprocessable_entity
          return
        end

        # Check if config already exists
        existing_config = campaign.agent_configs.find_by(agent_name: agent_name)
        if existing_config
          render json: { errors: [ "Agent config already exists for this campaign" ] }, status: :unprocessable_entity
          return
        end

        config = campaign.agent_configs.build(
          agent_name: agent_name,
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
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        config = campaign.agent_configs.find_by(id: params[:id])

        unless config
          render json: { errors: [ "Agent config not found" ] }, status: :not_found
          return
        end

        # Only allow updating enabled status and settings
        # Agent name cannot be changed
        update_params = agent_config_params.except(:agent_name, :agentName)

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
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        config = campaign.agent_configs.find_by(id: params[:id])

        if config
          config.destroy
          head :no_content
        else
          render json: { errors: [ "Agent config not found" ] }, status: :not_found
        end
      end

      private

      def agent_config_params
        # Permit all settings keys explicitly for security
        # Settings vary by agent type, so we permit all known keys
        permitted = params.require(:agent_config).permit(:agent_name, :agentName, :enabled)
        if params[:agent_config][:settings].present?
          permitted[:settings] = permit_settings(params[:agent_config][:settings])
        else
          permitted[:settings] = {}
        end
        permitted
      rescue ActionController::ParameterMissing
        # Allow empty params for flexibility
        permitted = params.permit(:agent_name, :agentName, :enabled)
        if params[:settings].present?
          permitted[:settings] = permit_settings(params[:settings])
        else
          permitted[:settings] = {}
        end
        permitted.with_indifferent_access
      end

      def permit_settings(settings_params)
        # Permit all known settings keys used by different agent types
        # WRITER: tone, sender_persona, email_length, personalization_level, primary_cta_type,
        #         cta_softness, num_variants_per_lead, product_info, sender_company
        # SEARCH: search_depth, max_queries_per_lead, extracted_fields, on_low_info_behavior
        # CRITIQUE: checks (hash), strictness, min_score_for_send, rewrite_policy, variant_selection
        # DESIGN: format, allow_bold, allow_italic, allow_bullets, cta_style, font_family
        settings_params.permit(
          # WRITER agent settings
          :tone, :sender_persona, :email_length, :personalization_level,
          :primary_cta_type, :cta_softness, :num_variants_per_lead,
          :product_info, :sender_company,
          # SEARCH agent settings
          :search_depth, :max_queries_per_lead, :on_low_info_behavior,
          # CRITIQUE agent settings
          :strictness, :min_score_for_send, :rewrite_policy, :variant_selection,
          # DESIGN agent settings
          :format, :allow_bold, :allow_italic, :allow_bullets, :cta_style, :font_family,
          # Nested structures
          checks: {},
          extracted_fields: []
        )
      end
    end
  end
end
