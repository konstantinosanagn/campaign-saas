module Api
  module V1
    class AgentConfigsController < BaseController
      ##
      # GET /api/v1/campaigns/:campaign_id/agent_configs
      # Returns all agent configs for a campaign
      def index
        # Use includes to prevent N+1 queries
        campaign = current_user.campaigns.includes(:agent_configs).find_by(id: params[:campaign_id])

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
        # Use includes to prevent N+1 queries
        campaign = current_user.campaigns.includes(:agent_configs).find_by(id: params[:campaign_id])

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
        # Use includes to prevent N+1 queries
        campaign = current_user.campaigns.includes(:agent_configs).find_by(id: params[:campaign_id])

        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        # Normalize agent_name (handle both camelCase and snake_case)
        # Rails converts top-level camelCase JSON keys to snake_case (agentConfig -> agent_config)
        # But nested keys may remain in camelCase (agentName stays as agentName)
        # Get agent_name from raw params (before permit filters it)
        raw_config = params[:agent_config] || params["agent_config"] || {}
        agent_name = raw_config[:agent_name] ||
                     raw_config[:agentName] ||
                     raw_config["agent_name"] ||
                     raw_config["agentName"]

        # Validate agent name
        unless AgentConstants::VALID_AGENT_NAMES.include?(agent_name)
          render json: { errors: [ "Invalid agent name. Must be one of: SEARCH, WRITER, CRITIQUE, DESIGN" ] }, status: :unprocessable_entity
          return
        end

        # Check if config already exists - reload association to avoid cache issues
        campaign.agent_configs.reload
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
        # Use includes to prevent N+1 queries
        campaign = current_user.campaigns.includes(:agent_configs).find_by(id: params[:campaign_id])

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
        # Use includes to prevent N+1 queries
        campaign = current_user.campaigns.includes(:agent_configs).find_by(id: params[:campaign_id])

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
        # Handle both camelCase (agentConfig) and snake_case (agent_config)
        # Rails converts top-level camelCase JSON keys to snake_case automatically
        # So "agentConfig" in JSON becomes "agent_config" in params
        # But nested keys may remain in camelCase
        config_params = params[:agent_config] || params["agent_config"]

        unless config_params
          # Fallback: try to get from top-level params
          return params.permit(:agent_name, :agentName, :enabled, settings: {})
        end

        # Permit all settings keys explicitly for security
        # Settings vary by agent type, so we permit all known keys
        # Note: permit accepts both symbol and string keys, and both camelCase and snake_case
        permitted = config_params.permit(:agent_name, :agentName, "agent_name", "agentName", :enabled)

        settings_data = config_params[:settings] || config_params["settings"]
        if settings_data.present?
          permitted[:settings] = permit_settings(settings_data)
        else
          permitted[:settings] = {}
        end

        permitted
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
