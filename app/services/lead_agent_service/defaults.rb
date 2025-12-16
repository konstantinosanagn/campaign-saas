class LeadAgentService
  module Defaults
    VERSION = "v1".freeze

    def self.for(agent_name)
      case agent_name
      when AgentConstants::AGENT_SEARCH
        {}
      when AgentConstants::AGENT_WRITER
        { "product_info" => "", "sender_company" => "" }
      when AgentConstants::AGENT_CRITIQUE
        {
          "strictness" => "moderate",
          "min_score_for_send" => 6,
          "rewrite_policy" => "rewrite_if_bad",
          "variant_selection" => "highest_overall_score",
          "checks" => {
            "check_personalization" => true,
            "check_brand_voice" => true,
            "check_spamminess" => true
          },
          # v1 LeadRun rewrite loop cap (planner derives lead_run.max_rewrites from this)
          "max_rewrites" => 2
        }
      when AgentConstants::AGENT_DESIGN
        {}
      when AgentConstants::AGENT_SENDER
        {}
      else
        {}
      end
    end
  end
end
