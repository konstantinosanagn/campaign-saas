##
# AgentConfigSerializer
#
# Serializes AgentConfig model to camelCase JSON format for API responses
#
class AgentConfigSerializer < BaseSerializer
  def as_json
    {
      "id" => @object.id,
      "agentName" => @object.agent_name,
      "enabled" => @object.enabled,
      "settings" => @object.settings,
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end
end
