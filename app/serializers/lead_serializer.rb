##
# LeadSerializer
#
# Serializes Lead model to camelCase JSON format for API responses
#
class LeadSerializer < BaseSerializer
  def as_json
    {
      "id" => @object.id,
      "name" => @object.name,
      "email" => @object.email,
      "title" => @object.title,
      "company" => @object.company,
      "website" => @object.website,
      "campaignId" => @object.campaign_id,
      "stage" => @object.stage,
      "quality" => @object.quality,
      "score" => critique_score,
      "meetsMinScore" => critique_meets_min_score,
      "availableActions" => available_actions,
      "rewriteCount" => rewrite_count,
      "leadRun" => lead_run,
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end

  private

  # Extract critique score from CRITIQUE agent output (latest one)
  def critique_score
    critique_output = latest_completed_output(agent_name: "CRITIQUE")
    return nil unless critique_output

    output_data = critique_output.output_data || {}
    score = output_data["score"] || output_data[:score]
    score.is_a?(Numeric) ? score.to_i : nil
  end

  # Extract meets_min_score flag from CRITIQUE agent output (latest one)
  def critique_meets_min_score
    critique_output = latest_completed_output(agent_name: "CRITIQUE")
    return nil unless critique_output

    output_data = critique_output.output_data || {}
    meets_min_score = output_data["meets_min_score"] || output_data[:meets_min_score]
    meets_min_score
  end

  # Get available actions for this lead
  def available_actions
    next_step = lead_run && (lead_run["nextStep"] || lead_run[:nextStep])
    agent = next_step && (next_step["agentName"] || next_step[:agentName])
    agent ? [agent] : []
  end

  # Get rewrite count for this lead
  def rewrite_count
    (lead_run && (lead_run["rewriteCount"] || lead_run[:rewriteCount])) || 0
  end

  def lead_run
    @lead_run ||= begin
      run = (@options[:active_runs_by_lead_id] || {})[@object.id]
      campaign = @object.campaign
      agent_configs = campaign.association(:agent_configs).loaded? ? campaign.agent_configs : nil
      camelize_keys(LeadRuns.status_payload_for(@object, run: run, campaign: campaign, agent_configs: agent_configs))
    end
  end

  def latest_completed_output(agent_name:)
    assoc = @object.association(:agent_outputs)

    if assoc.loaded?
      @object.agent_outputs
             .select { |o| o.agent_name.to_s == agent_name.to_s && o.status.to_s == "completed" }
             .max_by(&:created_at)
    else
      @object.agent_outputs
             .where(agent_name: agent_name.to_s, status: "completed")
             .order(created_at: :desc)
             .first
    end
  end
end
