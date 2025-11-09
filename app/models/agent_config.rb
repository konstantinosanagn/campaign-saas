class AgentConfig < ApplicationRecord
  belongs_to :campaign

  # Valid agent names - SEARCH, WRITER, DESIGN, and CRITIQUE agents are implemented
  VALID_AGENT_NAMES = %w[SEARCH WRITER DESIGN CRITIQUE].freeze

  # Validations
  validates :campaign_id, presence: true
  validates :agent_name, presence: true, inclusion: { in: VALID_AGENT_NAMES }
  # Allow empty hash for settings (SEARCH and CRITIQUE have no settings yet)
  validates :settings, exclusion: { in: [nil] } # Allow empty hash, but not nil
  validates :enabled, inclusion: { in: [true, false] }

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

