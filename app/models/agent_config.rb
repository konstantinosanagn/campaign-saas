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

  # Simple validation: settings must be a JSON object (Hash) when present
  # Allow empty hash, nested objects, and arrays - no deep type enforcement
  validate :settings_must_be_json_object

  private

  def settings_must_be_json_object
    # Allow nil or empty settings
    return if settings.nil? || settings == {}

    # Top-level must be a Hash (JSON object)
    unless settings.is_a?(Hash)
      errors.add(:settings, "must be a JSON object")
    end

    # Do NOT add restrictions on nested values here.
    # Arrays and hashes inside `settings` are fine.
    # We only validate that the top-level is a Hash, not the contents.
  end

  public

  # Status query methods
  def enabled?
    # Handle both boolean true and string "true" (JSONB might store as string)
    val = enabled
    val == true || val == "true" || val == 1
  end

  def disabled?
    # Handle both boolean false and string "false" (JSONB might store as string)
    val = enabled
    val == false || val == "false" || val == 0 || val.nil?
  end

  # Safe accessor methods for JSONB settings
  def get_setting(key)
    settings[key.to_s] || settings[key.to_sym]
  end

  def set_setting(key, value)
    self.settings = settings.merge(key.to_s => value)
  end
end
