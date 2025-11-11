class AgentOutput < ApplicationRecord
  include AgentConstants
  include JsonbValidator

  belongs_to :lead

  # Validations
  validates :lead_id, presence: true
  validates :agent_name, presence: true, inclusion: { in: VALID_AGENT_NAMES }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :output_data, presence: true

  # JSON schema validation for output_data (optional, won't break existing data)
  # This provides basic structure validation without being too strict
  validates_jsonb_schema :output_data, schema: {
    type: "object",
    properties: {
      email: { type: "string" },
      formatted_email: { type: "string" },
      company: { type: "string" },
      recipient: { type: "string" },
      sources: { type: "array" },
      critique: { type: "string" },
      score: { type: "integer" },
      variants: { type: "array" },
      selected_variant: { type: "string" },
      error: { type: "string" }
    }
  }, allow_empty: false, strict: false

  # Status query methods
  def completed?
    status == STATUS_COMPLETED
  end

  def failed?
    status == STATUS_FAILED
  end

  def pending?
    status == STATUS_PENDING
  end
end
