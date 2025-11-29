##
# AgentOutputSerializer
#
# Serializes AgentOutput model to camelCase JSON format for API responses
#
class AgentOutputSerializer < BaseSerializer
  def as_json
    {
      "agentName" => @object.agent_name,
      "status" => @object.status,
      "outputData" => @object.output_data,
      "errorMessage" => @object.error_message,
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end
end
