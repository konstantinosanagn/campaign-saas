class AgentDispatcher
  class DispatchError < StandardError; end
  require_relative "lead_runs/config_resolver"
  require_relative "lead_runs/prompt_settings_filter"

  def self.dispatch!(lead_run:, step:)
    new(lead_run: lead_run, step: step).dispatch!
  end

  def initialize(lead_run:, step:)
    @lead_run = lead_run
    @step = step
    @lead = lead_run.lead
    @campaign = lead_run.campaign
    @user = @campaign.user
  end

  def dispatch!
    agent_name = @step.agent_name
    settings = settings_for(agent_name)
    shared_settings = shared_settings_snapshot

    gemini_key = ApiKeyService.get_gemini_api_key(@user)
    tavily_key = ApiKeyService.get_tavily_api_key(@user)

    case agent_name
    when AgentConstants::AGENT_SEARCH
      agent = Agents::SearchAgent.new(tavily_key: tavily_key, gemini_key: gemini_key)
      agent.run(
        company: @lead.company,
        recipient_name: @lead.name,
        job_title: @lead.title || "",
        email: @lead.email,
        tone: shared_settings[:brand_voice]&.dig(:tone),
        persona: shared_settings[:brand_voice]&.dig(:persona),
        goal: shared_settings[:primary_goal],
        config: { settings: settings }
      )
    when AgentConstants::AGENT_WRITER
      agent = Agents::WriterAgent.new(api_key: gemini_key)

      search_output = latest_completed_output_data(agent_name: AgentConstants::AGENT_SEARCH)
      search_results = normalize_search_results(search_output)

      previous_critique = nil
      if @step.meta.is_a?(Hash)
        critique_step_id = @step.meta["critique_step_id"] || @step.meta[:critique_step_id]
        if critique_step_id
          critique_output = AgentOutput.find_by!(lead_run_step_id: critique_step_id)
          previous_critique =
            critique_output.output_data["critique"] ||
            critique_output.output_data[:critique]
        end
      end

      sender_name = @user&.name || @user&.first_name || ""

      result = agent.run(
        search_results,
        recipient: @lead.name,
        company: @lead.company,
        product_info: settings[:product_info],
        sender_company: settings[:sender_company],
        config: { settings: settings },
        shared_settings: shared_settings,
        previous_critique: previous_critique,
        sender_name: sender_name
      )

      if sender_name.present? && result.is_a?(Hash)
        result = result.deep_dup
        if result[:email].present?
          result[:email] = LeadAgentService::Executor.replace_placeholders(result[:email], sender_name)
        end
        if result[:variants].is_a?(Array)
          result[:variants] = result[:variants].map { |variant| LeadAgentService::Executor.replace_placeholders(variant, sender_name) }
        end
      end

      result
    when AgentConstants::AGENT_CRITIQUE
      agent = Agents::CritiqueAgent.new(api_key: gemini_key)

      writer_step_id = meta_required!("writer_step_id")
      selected_variant_index = (meta_optional("selected_variant_index") || 0).to_i

      writer_output = AgentOutput.find_by!(lead_run_step_id: writer_step_id)
      writer_data = writer_output.output_data || {}

      variants = writer_data["variants"] || writer_data[:variants] || []
      email_content =
        if variants.is_a?(Array) && variants.any?
          variants[selected_variant_index] || variants.first
        else
          writer_data["email"] || writer_data[:email] || writer_data["formatted_email"] || writer_data[:formatted_email]
        end

      # v1 determinism: critique exactly one variant (selected_variant_index), not a multi-variant tournament.
      # Passing variants to CritiqueAgent would trigger its variant selection logic.
      variants_for_agent = []

      article = {
        "email_content" => email_content.to_s,
        "variants" => variants_for_agent,
        "number_of_revisions" => (@step.meta["revision"] || @step.meta[:revision] || 0).to_i
      }

      result = agent.run(article, config: { settings: settings })

      # Ensure the critique output includes the canonical score key if present.
      result
    when AgentConstants::AGENT_DESIGN
      agent = Agents::DesignAgent.new(api_key: gemini_key)

      critique_output = latest_completed_critique_output_data_before_design
      selected_email = select_email_from_critique_output(critique_output)
      writer_output = latest_completed_output_data(agent_name: AgentConstants::AGENT_WRITER)
      fallback_email = writer_output ? (writer_output["email"] || writer_output[:email]) : nil

      email_to_format = selected_email.presence || fallback_email.to_s

      agent.run(
        {
          email: email_to_format,
          company: @lead.company,
          recipient: @lead.name
        },
        config: { settings: settings }
      )
    else
      raise DispatchError, "Unknown agent_name: #{agent_name}"
    end
  end

  private

  def settings_for(agent_name)
    # Prefer per-step snapshot (claim-time resolution) for determinism.
    if @step.meta.is_a?(Hash)
      raw =
        @step.meta["settings_snapshot"] ||
        @step.meta[:settings_snapshot]

      if raw.present?
        unfiltered = raw || {}
        # Filter out prompt-incompatible settings before passing to agent
        return LeadRuns::PromptSettingsFilter.filter(agent_name: agent_name, settings: unfiltered)
      end
    end

    # Backward-compat: resolve read-only if snapshot missing.
    resolved = LeadRuns::ConfigResolver.resolve(campaign: @campaign, agent_name: agent_name)
    unfiltered = resolved[:settings_snapshot] || {}
    LeadRuns::PromptSettingsFilter.filter(agent_name: agent_name, settings: unfiltered)
  end

  def shared_settings_snapshot
    (@lead_run.config_snapshot["shared_settings"] || @lead_run.config_snapshot[:shared_settings] || {}).deep_symbolize_keys
  end

  def latest_completed_output_data(agent_name:)
    step = @lead_run.steps.where(agent_name: agent_name, status: "completed").order(position: :desc).first
    step&.agent_output&.output_data
  end

  def normalize_search_results(search_output)
    if search_output.nil?
      return { company: @lead.company, sources: [], inferred_focus_areas: [] }
    end

    data = search_output.deep_symbolize_keys
    recipient_sources = Array(data.dig(:personalization_signals, :recipient))
    company_sources = Array(data.dig(:personalization_signals, :company))

    {
      company: @lead.company,
      sources: (recipient_sources + company_sources).uniq,
      inferred_focus_areas: data[:inferred_focus_areas] || []
    }
  end

  def meta_required!(key)
    val = meta_optional(key)
    raise DispatchError, "Missing required step.meta.#{key}" if val.nil?
    val
  end

  def meta_optional(key)
    return nil unless @step.meta.is_a?(Hash)
    @step.meta[key.to_s] || @step.meta[key.to_sym]
  end

  def latest_completed_critique_output_data_before_design
    @lead_run.steps
             .where(agent_name: AgentConstants::AGENT_CRITIQUE, status: "completed")
             .order(position: :desc)
             .first
             &.agent_output
             &.output_data
  end

  def select_email_from_critique_output(output_data)
    return nil unless output_data
    data = output_data.with_indifferent_access
    data["selected_variant"] || data["email_content"] || data["email"]
  end
end
