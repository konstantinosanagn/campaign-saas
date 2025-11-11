class AgentConfig < ApplicationRecord
  include AgentConstants
  include JsonbValidator

  belongs_to :campaign

  # Validations
  validates :campaign_id, presence: true
  validates :agent_name, presence: true, inclusion: { in: VALID_AGENT_NAMES }
  # Allow empty hash for settings (SEARCH and CRITIQUE have no settings yet)
  validates :settings, exclusion: { in: [ nil ] } # Allow empty hash, but not nil
  validates :enabled, inclusion: { in: [ true, false ] }

  # JSON schema validation for settings (optional, won't break existing data)
  # This provides basic type checking without being too strict
  validates_jsonb_schema :settings, schema: {
    type: "object",
    properties: {
      # WRITER agent settings
      tone: { type: "string" },
      sender_persona: { type: "string" },
      email_length: { type: "string" },
      personalization_level: { type: "string" },
      primary_cta_type: { type: "string" },
      cta_softness: { type: "string" },
      num_variants_per_lead: { type: "integer" },
      product_info: { type: "string" },
      sender_company: { type: "string" },
      # SEARCH agent settings
      search_depth: { type: "string" },
      max_queries_per_lead: { type: "integer" },
      on_low_info_behavior: { type: "string" },
      extracted_fields: { type: "array" },
      # CRITIQUE agent settings
      strictness: { type: "string" },
      min_score_for_send: { type: "integer" },
      rewrite_policy: { type: "string" },
      variant_selection: { type: "string" },
      checks: { type: "object" },
      # DESIGN agent settings
      format: { type: "string" },
      allow_bold: { type: "boolean" },
      allow_italic: { type: "boolean" },
      allow_bullets: { type: "boolean" },
      cta_style: { type: "string" },
      font_family: { type: "string" }
    }
  }, allow_empty: true, strict: false

  # Status query methods
  def enabled?
    enabled == true
  end

  def disabled?
    enabled == false
  end

  # Safe accessor methods for JSONB settings
  def get_setting(key)
    settings[key.to_s] || settings[key.to_sym]
  end

  def set_setting(key, value)
    self.settings = settings.merge(key.to_s => value)
  end
end
