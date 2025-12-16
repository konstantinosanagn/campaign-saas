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
          # Config already exists - update it instead of creating a new one
          # This handles the case where ConfigManager auto-created a default config
          # but the frontend doesn't have it loaded yet
          Rails.logger.info("[AgentConfigsController] Config already exists (ID: #{existing_config.id}), updating instead of creating")

          # Get permitted params
          permitted_params = agent_config_params

          # Build update hash (excluding agent_name since it can't be changed)
          update_hash = {}
          update_hash[:enabled] = permitted_params[:enabled] if permitted_params.key?(:enabled)
          update_hash[:settings] = permitted_params[:settings] if permitted_params.key?(:settings)

          Rails.logger.info("[AgentConfigsController] Updating existing config id=#{existing_config.id} agent_name=#{existing_config.agent_name} keys=#{update_hash.keys}")

          if agent_config_locked?(campaign_id: campaign.id, agent_name: existing_config.agent_name)
            render json: { error: "agent_config_locked", agent_name: existing_config.agent_name }, status: :unprocessable_entity
            return
          end

          if existing_config.update(update_hash)
            existing_config.reload
            Rails.logger.info("[AgentConfigsController] Config updated successfully id=#{existing_config.id} enabled=#{existing_config.enabled}")

            # Reconcile active runs for this campaign to reflect the config change
            active_runs = LeadRun.where(campaign_id: campaign.id, status: LeadRun::ACTIVE_STATUSES)
            active_runs.find_each do |run|
              LeadRuns.reconcile_disabled_steps!(run, campaign)
              LeadRuns.reconcile_enabled_steps!(run, campaign)
              if existing_config.agent_name == "DESIGN" && existing_config.enabled?
                LeadRuns.ensure_design_step!(run)
              end
            end

            render json: AgentConfigSerializer.serialize(existing_config), status: :ok
          else
            Rails.logger.error("[AgentConfigsController] Config update failed: #{existing_config.errors.full_messages.join(', ')}")
            render json: { errors: existing_config.errors.full_messages }, status: :unprocessable_entity
          end
          return
        end

        # No existing config - create a new one
        config = campaign.agent_configs.build(
          agent_name: agent_name,
          enabled: agent_config_params[:enabled] != false, # Default to true
          settings: agent_config_params[:settings] || {}
        )

        if config.save
          # Reconcile active runs for this campaign to reflect the new config
          active_runs = LeadRun.where(campaign_id: campaign.id, status: LeadRun::ACTIVE_STATUSES)
          active_runs.find_each do |run|
            LeadRuns.reconcile_disabled_steps!(run, campaign)
            LeadRuns.reconcile_enabled_steps!(run, campaign)
            if config.agent_name == "DESIGN" && config.enabled?
              LeadRuns.ensure_design_step!(run)
            end
          end

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

        # Get permitted params
        permitted_params = agent_config_params

        # Only allow updating enabled status and settings
        # Agent name cannot be changed - build update hash excluding agent_name
        update_hash = {}
        update_hash[:enabled] = permitted_params[:enabled] if permitted_params.key?(:enabled)
        update_hash[:settings] = permitted_params[:settings] if permitted_params.key?(:settings)

        # Log the update params for debugging
        settings_keys = update_hash[:settings].is_a?(Hash) ? update_hash[:settings].keys : nil
        Rails.logger.info("[AgentConfigsController] Updating config id=#{config.id} agent_name=#{config.agent_name} keys=#{update_hash.keys} settings_keys=#{settings_keys}")

        if agent_config_locked?(campaign_id: campaign.id, agent_name: config.agent_name)
          render json: { error: "agent_config_locked", agent_name: config.agent_name }, status: :unprocessable_entity
          return
        end

        if config.update(update_hash)
          # Reload to ensure we have the latest values
          config.reload
          Rails.logger.info("[AgentConfigsController] Config updated successfully id=#{config.id} enabled=#{config.enabled}")

          # Reconcile active runs for this campaign to reflect the config change
          active_runs = LeadRun.where(campaign_id: campaign.id, status: LeadRun::ACTIVE_STATUSES)
          active_runs.find_each do |run|
            LeadRuns.reconcile_disabled_steps!(run, campaign)
            LeadRuns.reconcile_enabled_steps!(run, campaign)
            if config.agent_name == "DESIGN" && config.enabled?
              LeadRuns.ensure_design_step!(run)
            end
          end

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
          if agent_config_locked?(campaign_id: campaign.id, agent_name: config.agent_name)
            render json: { error: "agent_config_locked", agent_name: config.agent_name }, status: :unprocessable_entity
            return
          end

          config.destroy
          head :no_content
        else
          render json: { errors: [ "Agent config not found" ] }, status: :not_found
        end
      end

      private

      def agent_config_locked?(campaign_id:, agent_name:)
        LeadRunStep.joins(:lead_run).where(
          lead_runs: { campaign_id: campaign_id, status: LeadRun::ACTIVE_STATUSES },
          agent_name: agent_name.to_s,
          status: "running"
        ).exists?
      end

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

        # Permit enabled and settings (explicitly permit settings to avoid unpermitted parameter warning)
        # Note: Do NOT permit :id - it comes from the URL params[:id] and should not be in the payload
        # We permit settings: {} here to avoid the warning, then filter nested keys in permit_settings
        permitted = config_params.permit(
          :agent_name, :agentName, "agent_name", "agentName",
          :enabled,
          settings: {}
        )

        # Extract and process settings separately to handle nested structures properly
        # This ensures we only permit the specific keys we want
        settings_data = config_params[:settings] || config_params["settings"]
        permitted_settings = if settings_data.present?
          permit_settings(settings_data)
        else
          {}
        end

        # Convert to hash and merge settings
        result = permitted.to_h
        result[:settings] = permitted_settings
        result
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

        # Convert to ActionController::Parameters if it's a plain hash
        params_obj = if settings_params.is_a?(ActionController::Parameters)
          settings_params
        elsif settings_params.is_a?(Hash)
          ActionController::Parameters.new(settings_params)
        else
          ActionController::Parameters.new({})
        end

        params_obj.permit(
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
        ).to_h
      end
    end
  end
end
