require "set"
require_relative "../lead_run_executor"

module LeadRuns
  class PromptSettingsFilter
    # Use executor's constant as source of truth to avoid divergence
    LLM_AGENTS = Set.new(LeadRunExecutor::LLM_AGENT_NAMES).freeze
    # Normalize to string to handle both symbol and string keys, plus edge cases
    STRIP_KEY_STRINGS = Set.new([ "min_score_for_send" ]).freeze

    def self.filter(agent_name:, settings:)
      return settings || {} unless LLM_AGENTS.include?(agent_name.to_s)
      deep_strip(settings || {})
    end

    def self.deep_strip(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          # Normalize key to string for comparison (handles both :symbol and "string" keys)
          next if STRIP_KEY_STRINGS.include?(k.to_s)
          acc[k] = deep_strip(v)
        end
      when Array
        obj.map { |v| deep_strip(v) }
      else
        obj
      end
    end
  end
end
