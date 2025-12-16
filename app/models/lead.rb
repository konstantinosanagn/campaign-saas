class Lead < ApplicationRecord
  belongs_to :campaign
  # Order matters: destroy lead_runs first (which destroys lead_run_steps),
  # then destroy agent_outputs (after references are cleared)
  has_many :lead_runs, dependent: :destroy
  has_many :agent_outputs, dependent: :destroy
  belongs_to :current_lead_run, class_name: "LeadRun", optional: true

  validates :name, :email, :title, :company, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save :set_default_website
  before_destroy :clear_agent_output_references

  # Email status query methods
  def email_sent?
    email_status == "sent"
  end

  def email_sending?
    email_status == "sending"
  end

  def email_failed?
    email_status == "failed"
  end

  def email_not_scheduled?
    email_status == "not_scheduled"
  end

  # DB-truth active run lookup (pointer is cache only).
  #
  # Contract:
  # - Query DB for latest active run (queued/running)
  # - Ignore stale pointers to terminal runs
  # - Auto-heal: Treat stuck SENDER runs as inactive if email is already sent/failed
  def active_run
    return nil unless defined?(LeadRun)

    run = lead_runs.where(status: LeadRun::ACTIVE_STATUSES).order(created_at: :desc).first
    return nil unless run

    # Auto-heal: If run is stuck with only SENDER step and email is already sent/failed,
    # treat it as inactive to prevent UI from showing loading state
    if run.status.in?(%w[queued running])
      steps = run.steps.to_a
      if steps.length == 1 && steps.first.agent_name == AgentConstants::AGENT_SENDER
        sender_step = steps.first
        # Check if email is already sent or failed (indicating job completed but step wasn't finalized)
        if email_status == "sent" || email_status == "failed" || 
           stage&.start_with?("sent (") || stage == "send_failed"
          Rails.logger.warn(
            "[Lead#active_run] Auto-healing stuck SENDER run_id=#{run.id} step_id=#{sender_step.id} " \
            "lead_id=#{id} email_status=#{email_status} stage=#{stage}"
          )
          # Attempt to finalize the run (best effort, don't fail if it doesn't work)
          begin
            LeadRunExecutor.recompute_run_status!(run_id: run.id)
          rescue => e
            Rails.logger.error("[Lead#active_run] Failed to auto-heal run_id=#{run.id}: #{e.class} - #{e.message}")
          end
          # Return nil to treat as inactive
          return nil
        end
      end
    end

    run
  end

  # Creates a run only when none exists.
  # (Planner is added in later commits; this method becomes the canonical entrypoint.)
  def ensure_active_run!
    run = active_run
    return run if run

    LeadRuns.ensure_active_run_for!(self)
  end

  private

  def set_default_website
    self.website = email.split("@")[1] if website.to_s.strip.empty?
  end

  # Clear foreign key references before destroying
  # This prevents foreign key constraint violations when deleting leads
  #
  # Note: current_lead_run_id is cleared in LeadRun#before_destroy callback
  # (which runs when lead_runs are destroyed via dependent: :destroy)
  #
  # Foreign key relationships that need to be cleared here:
  # 1. agent_outputs.lead_run_id -> lead_runs.id (cleared in LeadRun#before_destroy)
  # 2. agent_outputs.lead_run_step_id -> lead_run_steps.id (cleared in LeadRun#before_destroy)
  # 3. lead_run_steps.agent_output_id -> agent_outputs.id (cleared in LeadRun#before_destroy)
  #
  # This callback handles any remaining references that might not be caught by LeadRun callbacks
  def clear_agent_output_references
    # Clear lead_run_id and lead_run_step_id in agent_outputs as a safety net
    # (LeadRun#before_destroy should handle this, but this ensures it's done)
    AgentOutput.where(lead_id: id)
               .where("lead_run_id IS NOT NULL OR lead_run_step_id IS NOT NULL")
               .update_all(lead_run_id: nil, lead_run_step_id: nil)

    # Clear agent_output_id in lead_run_steps as a safety net
    # (LeadRun#before_destroy should handle this, but this ensures it's done)
    LeadRunStep.joins(:lead_run)
               .where(lead_runs: { lead_id: id })
               .where.not(agent_output_id: nil)
               .update_all(agent_output_id: nil)
  end
end
