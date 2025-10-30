class AgentOutput < ApplicationRecord
  belongs_to :lead

  # Valid agent names - only these three agents are implemented
  VALID_AGENT_NAMES = %w[SEARCH WRITER CRITIQUE].freeze

  # Valid status values
  VALID_STATUSES = %w[pending completed failed].freeze

  # Validations
  validates :lead_id, presence: true
  validates :agent_name, presence: true, inclusion: { in: VALID_AGENT_NAMES }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :output_data, presence: true

  # Status query methods
  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end
end

