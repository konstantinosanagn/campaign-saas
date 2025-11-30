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

        configs = campaign.agent_configs.map { |config| AgentConfigSerializer.serialize(config) }

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

        render json: AgentConfigSerializer.serialize(config), status: :ok
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
          render json: AgentConfigSerializer.serialize(config), status: :created
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

        # Ensure enabled is explicitly set if provided (Rails permit might exclude false values)
        if agent_config_params.key?(:enabled) || agent_config_params.key?("enabled")
          enabled_value = agent_config_params[:enabled] || agent_config_params["enabled"]
          update_params[:enabled] = enabled_value unless enabled_value.nil?
        end

        # Log the update params for debugging
        Rails.logger.info("[AgentConfigsController] Updating config #{config.id} (#{config.agent_name}) with params: #{update_params.inspect}")
        
        if config.update(update_params)
          # Reload to ensure we have the latest values
          config.reload
          Rails.logger.info("[AgentConfigsController] Config updated successfully: enabled=#{config.enabled}")
          render json: AgentConfigSerializer.serialize(config), status: :ok
        else
          Rails.logger.error("[AgentConfigsController] Config update failed: #{config.errors.full_messages.join(', ')}")
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
        # DESIGN: format, allow_bold/allowBold, allow_italic/allowItalic, allow_bullets/allowBullets,
        #         cta_style/ctaStyle, font_family/fontFamily
        # Note: DESIGN agent settings accept both camelCase (from frontend) and snake_case (for consistency)
        settings_params.permit(
          # WRITER agent settings
          :tone, :sender_persona, :email_length, :personalization_level,
          :primary_cta_type, :cta_softness, :num_variants_per_lead,
          :product_info, :sender_company,
          # SEARCH agent settings
          :search_depth, :max_queries_per_lead, :on_low_info_behavior,
          # CRITIQUE agent settings
          :strictness, :min_score_for_send, :rewrite_policy, :variant_selection,
          # DESIGN agent settings - accept both camelCase (from frontend) and snake_case
          :format,
          :allow_bold, :allowBold,
          :allow_italic, :allowItalic,
          :allow_bullets, :allowBullets,
          :cta_style, :ctaStyle,
          :font_family, :fontFamily,
          # Nested structures
          checks: {},
          extracted_fields: []
        )
      end
    end
  end
end
