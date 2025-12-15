class AgentOutput < ApplicationRecord
  include AgentConstants
  include JsonbValidator

  belongs_to :lead
  belongs_to :lead_run, optional: true
  belongs_to :lead_run_step, optional: true

  # Validations
  validates :lead_id, presence: true
  validates :agent_name, presence: true, inclusion: { in: VALID_AGENT_NAMES }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :output_data, presence: true

  # JSON schema validation for output_data (optional, won't break existing data)
  # This provides basic structure validation without being too strict
  # Note: Only validates properties that exist - allows flexible data structures
  validates_jsonb_schema :output_data, schema: {
    type: "object",
    properties: {
      email: { type: "string" },
      formatted_email: { type: "string" },
      company: { type: "string" },
      recipient: { type: "string" },
      sources: { type: "array" },
      domain: { type: "object" },  # SEARCH agent output (nested object)
      critique: { type: "string" },
      score: { type: "integer" },
      variants: { type: "array" },
      selected_variant: { type: "string" },
      error: { type: "string" },
      image: { type: "string" },  # SEARCH agent may return image URL
      product_info: { type: "string" },  # WRITER agent output
      sender_company: { type: "string" }  # WRITER agent output
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
