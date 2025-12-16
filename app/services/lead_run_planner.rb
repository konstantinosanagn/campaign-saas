require "digest"
require "json"

class LeadRunPlanner
  class PlannerError < StandardError; end

  PLANNER_VERSION = "v1".freeze

  ORDER = [
    AgentConstants::AGENT_SEARCH,
    AgentConstants::AGENT_WRITER,
    AgentConstants::AGENT_CRITIQUE,
    AgentConstants::AGENT_DESIGN,
    AgentConstants::AGENT_SENDER
  ].freeze

  def self.build!(lead:)
    new(lead: lead).build!
  end

  def initialize(lead:)
    @lead = lead
    @campaign = lead.campaign
    @user = @campaign.user
  end

  def build!
    enabled = enabled_agent_names
    validate_enabled_agents!(enabled)
    validate_sender_enabled!(enabled)

    ActiveRecord::Base.transaction do
      run = LeadRun.create!(
        lead: @lead,
        campaign: @campaign,
        status: "queued",
        rewrite_count: 0,
        min_score: derived_min_score,
        max_rewrites: derived_max_rewrites,
        plan: { "steps" => enabled.map { |name| { "agent_name" => name } } },
        config_snapshot: build_config_snapshot(enabled)
      )

      # Build steps (create first, then set linkage meta using real IDs).
      position = 10
      writer_step = nil
      design_step = nil
      sender_step = nil

      enabled.each do |agent_name|
        step = LeadRunStep.create!(
          lead_run: run,
          position: position,
          agent_name: agent_name,
          status: "queued",
          meta: {}
        )
        position += 10

        case agent_name
        when AgentConstants::AGENT_WRITER
          writer_step = step
        when AgentConstants::AGENT_DESIGN
          design_step = step
        when AgentConstants::AGENT_SENDER
          sender_step = step
        when AgentConstants::AGENT_CRITIQUE
          raise PlannerError, "critique_requires_writer" unless writer_step
          step.update!(
            meta: {
              "writer_step_id" => writer_step.id,
              "selected_variant_index" => 0
            }
          )
        end
      end

      if sender_step
        raise PlannerError, "send_requires_writer" unless writer_step

        source_step_id = design_step ? design_step.id : writer_step.id
        sender_step.update!(meta: { "source_step_id" => source_step_id })
      end

      @lead.update!(current_lead_run: run)

      run
    end
  end

  private

  def enabled_agent_names
    ORDER.select do |agent_name|
      enabled_for_campaign?(agent_name)
    end
  end

  def enabled_for_campaign?(agent_name)
    if agent_name == AgentConstants::AGENT_SENDER
      # Do NOT auto-create SENDER config; treat missing as disabled.
      cfg = AgentConfig.find_by(campaign_id: @campaign.id, agent_name: agent_name)
      return false unless cfg
      cfg.enabled?
    else
      LeadAgentService::ConfigManager.get_agent_config(@campaign, agent_name).enabled?
    end
  end

  def validate_enabled_agents!(enabled)
    if enabled.empty?
      raise PlannerError, "no_agents_enabled"
    end

    writer_enabled = enabled.include?(AgentConstants::AGENT_WRITER)
    if enabled.include?(AgentConstants::AGENT_CRITIQUE) && !writer_enabled
      raise PlannerError, "critique_requires_writer"
    end
    if enabled.include?(AgentConstants::AGENT_DESIGN) && !writer_enabled
      raise PlannerError, "design_requires_writer"
    end
    if enabled.include?(AgentConstants::AGENT_SENDER) && !writer_enabled
      raise PlannerError, "send_requires_writer"
    end
  end

  def validate_sender_enabled!(enabled)
    return unless enabled.include?(AgentConstants::AGENT_SENDER)

    result = EmailDeliveryConfig.check(user: @user, campaign: @campaign)
    return if result[:ok]

    # Raise error with machine-readable reasons
    reasons = result[:reasons] || []
    raise PlannerError.new("sending_not_configured", reasons: reasons)
  end

  def build_config_snapshot(enabled)
    shared = @campaign.shared_settings || {}

    snapshot = {
      "planner_version" => PLANNER_VERSION,
      "defaults_version" => LeadAgentService::Defaults::VERSION,
      "shared_settings_hash" => shared_settings_hash(shared),
      "shared_settings" => shared,
      "planned_at" => Time.current.iso8601,
      "agents" => {}
    }

    enabled.each do |agent_name|
      cfg = AgentConfig.find_by(campaign_id: @campaign.id, agent_name: agent_name)
      agent_settings = cfg&.settings || {}
      system_defaults = LeadAgentService::Defaults.for(agent_name)

      merged =
        deep_merge(system_defaults, deep_merge(shared, agent_settings))

      snapshot["agents"][agent_name] = {
        "settings" => merged,
        "agent_config_id" => cfg&.id,
        "agent_config_updated_at" => cfg&.updated_at&.iso8601
      }
    end

    snapshot
  end

  def derived_min_score
    critique = LeadAgentService::Defaults.for(AgentConstants::AGENT_CRITIQUE)
    cfg = AgentConfig.find_by(campaign_id: @campaign.id, agent_name: AgentConstants::AGENT_CRITIQUE)
    agent_settings = cfg&.settings || {}
    shared = @campaign.shared_settings || {}
    merged = deep_merge(critique, deep_merge(shared, agent_settings))
    (merged["min_score_for_send"] || 6).to_i
  end

  def derived_max_rewrites
    critique = LeadAgentService::Defaults.for(AgentConstants::AGENT_CRITIQUE)
    cfg = AgentConfig.find_by(campaign_id: @campaign.id, agent_name: AgentConstants::AGENT_CRITIQUE)
    agent_settings = cfg&.settings || {}
    shared = @campaign.shared_settings || {}
    merged = deep_merge(critique, deep_merge(shared, agent_settings))
    (merged["max_rewrites"] || 2).to_i
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

  def shared_settings_hash(shared)
    Digest::SHA256.hexdigest(canonical_json(shared))
  end

  def canonical_json(obj)
    JSON.generate(canonicalize(obj))
  end

  def canonicalize(obj)
    case obj
    when Hash
      obj.keys.sort.map { |k| [ k.to_s, canonicalize(obj[k]) ] }.to_h
    when Array
      obj.map { |v| canonicalize(v) }
    else
      obj
    end
  end
end
