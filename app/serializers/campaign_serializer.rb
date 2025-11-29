##
# CampaignSerializer
#
# Serializes Campaign model to camelCase JSON format for API responses
#
class CampaignSerializer < BaseSerializer
  def as_json
    {
      "id" => @object.id,
      "title" => @object.title,
      "sharedSettings" => @object.shared_settings,
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end
end
