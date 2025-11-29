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
      "createdAt" => @object.created_at,
      "updatedAt" => @object.updated_at
    }
  end
end
