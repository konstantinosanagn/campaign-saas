module LeadRuns
  class ConfigResolver
    class << self
      # Resolve the effective settings for an agent at claim-time.
      #
      # Returns:
      #   {
      #     enabled: true/false,
      #     settings_snapshot: Hash,
      #     config_id: Integer|nil,
      #     config_updated_at: Time|nil
      #   }
      def resolve(campaign:, agent_name:)
        agent_name = agent_name.to_s

        # Missing SENDER config => disabled (we do not auto-create SENDER configs).
        if agent_name == AgentConstants::AGENT_SENDER
          cfg = AgentConfig.find_by(campaign_id: campaign.id, agent_name: agent_name)
          return build_result(enabled: cfg.present? && cfg.enabled?, cfg: cfg, campaign: campaign, agent_name: agent_name)
        end

        cfg = LeadAgentService::ConfigManager.get_agent_config(campaign, agent_name)
        build_result(enabled: cfg.enabled?, cfg: cfg, campaign: campaign, agent_name: agent_name)
      end

      private

      def build_result(enabled:, cfg:, campaign:, agent_name:)
        shared = campaign.shared_settings || {}
        defaults = LeadAgentService::Defaults.for(agent_name) || {}
        agent_settings = (cfg&.settings || {})

        merged = deep_merge(defaults, deep_merge(shared, agent_settings))

        {
          enabled: enabled,
          settings_snapshot: merged,
          config_id: cfg&.id,
          config_updated_at: cfg&.updated_at
        }
      end

      def deep_merge(a, b)
        a = a || {}
        b = b || {}
        a.merge(b) do |_k, old_v, new_v|
          if old_v.is_a?(Hash) && new_v.is_a?(Hash)
            deep_merge(old_v, new_v)
          else
            new_v
          end
        end
      end
    end
  end
end
