class LeadRun < ApplicationRecord
  STATUSES = %w[queued running completed failed cancelled].freeze
  ACTIVE_STATUSES = %w[queued running].freeze
  TERMINAL_STATUSES = %w[completed failed cancelled].freeze

  belongs_to :lead
  belongs_to :campaign

  has_many :steps,
           -> { order(:position) },
           class_name: "LeadRunStep",
           inverse_of: :lead_run,
           dependent: :destroy

  # Clear foreign key references before destroying
  # This prevents foreign key constraint violations when deleting runs
  #
  # Foreign key relationships that need to be cleared:
  # 1. leads.current_lead_run_id -> lead_runs.id (for the lead that owns this run)
  # 2. agent_outputs.lead_run_id -> lead_runs.id
  # 3. agent_outputs.lead_run_step_id -> lead_run_steps.id (for steps in this run)
  # 4. lead_run_steps.agent_output_id -> agent_outputs.id (for steps in this run)
  before_destroy :clear_references

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :min_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :terminal, -> { where(status: TERMINAL_STATUSES) }

  private

  # Clear all references before destroying this run and its steps
  def clear_references
    step_ids = steps.pluck(:id)

    # Clear current_lead_run_id in the lead that owns this run (so this run can be destroyed)
    Lead.where(current_lead_run_id: id).update_all(current_lead_run_id: nil)

    # Clear lead_run_id in agent_outputs (so this run can be destroyed)
    AgentOutput.where(lead_run_id: id).update_all(lead_run_id: nil)

    # Clear lead_run_step_id in agent_outputs for steps in this run (so steps can be destroyed)
    AgentOutput.where(lead_run_step_id: step_ids).update_all(lead_run_step_id: nil) if step_ids.any?

    # Clear agent_output_id in steps (so agent_outputs can be destroyed later)
    steps.where.not(agent_output_id: nil).update_all(agent_output_id: nil)
  end
end
