class LeadRunStep < ApplicationRecord
  STATUSES = %w[queued running completed failed skipped].freeze

  belongs_to :lead_run, inverse_of: :steps
  belongs_to :agent_output, optional: true

  # Clear foreign key references before destroying
  # This prevents foreign key constraint violations when deleting steps
  before_destroy :clear_agent_output_reference

  validates :position, presence: true
  validates :agent_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  private

  # Clear lead_run_step_id in the associated agent_output before destroying this step
  # This prevents the foreign key constraint violation: agent_outputs.lead_run_step_id -> lead_run_steps.id
  def clear_agent_output_reference
    # Clear lead_run_step_id in any agent_output that references this step
    AgentOutput.where(lead_run_step_id: id).update_all(lead_run_step_id: nil) if id.present?
  end
end
