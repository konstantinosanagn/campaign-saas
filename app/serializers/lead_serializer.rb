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
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end

  private

  # Extract critique score from CRITIQUE agent output (latest one)
  def critique_score
    critique_output = @object.agent_outputs
                              .where(agent_name: "CRITIQUE", status: "completed")
                              .order(created_at: :desc)
                              .first
    return nil unless critique_output

    output_data = critique_output.output_data || {}
    score = output_data["score"] || output_data[:score]
    score.is_a?(Numeric) ? score.to_i : nil
  end

  # Extract meets_min_score flag from CRITIQUE agent output (latest one)
  def critique_meets_min_score
    critique_output = @object.agent_outputs
                              .where(agent_name: "CRITIQUE", status: "completed")
                              .order(created_at: :desc)
                              .first
    return nil unless critique_output

    output_data = critique_output.output_data || {}
    meets_min_score = output_data["meets_min_score"] || output_data[:meets_min_score]
    meets_min_score
  end

  # Get available actions for this lead
  def available_actions
    LeadAgentService::StageManager.determine_available_actions(@object)
  end

  # Get rewrite count for this lead
  def rewrite_count
    LeadAgentService::StageManager.calculate_rewrite_count(@object)
  end
end
