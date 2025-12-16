module LeadRuns
  class Resume
    def self.call(lead_run_id:)
      new(lead_run_id: lead_run_id).call
    end

    def initialize(lead_run_id:)
      @lead_run_id = lead_run_id
    end

    def call
      result = nil

      LeadRun.transaction do
        run = LeadRun.lock.find(@lead_run_id)

        if run.status.in?(LeadRun::TERMINAL_STATUSES)
          result = { enqueue: false, lead_run_id: run.id, status: run.status, reason: "terminal" }
          next
        end

        running_step = run.steps.where(status: "running").order(:position).first
        if running_step
          if running_step.step_started_at.nil?
            Rails.logger.error("[LeadRuns::Resume] run_id=#{run.id} corrupted_running_step_missing_started_at step_id=#{running_step.id} agent=#{running_step.agent_name}")
            result = { enqueue: false, lead_run_id: run.id, status: run.status, reason: "corrupt_running_step" }
            next
          end

          # If an output already exists, we can safely enqueue to finalize.
          if AgentOutput.exists?(lead_run_step_id: running_step.id)
            result = { enqueue: true, lead_run_id: run.id, status: run.status, reason: "running_has_output" }
            next
          end

          # Stale running step: enqueue so executor can repair/finalize.
          threshold = Time.current - LeadRunExecutor::RUNNING_STEP_TIMEOUT
          if running_step.step_started_at < threshold
            result = { enqueue: true, lead_run_id: run.id, status: run.status, reason: "stale_running" }
          else
            result = { enqueue: false, lead_run_id: run.id, status: run.status, reason: "already_running" }
          end
          next
        end

        queued_exists = run.steps.where(status: "queued").exists?
        result = { enqueue: queued_exists, lead_run_id: run.id, status: run.status, reason: (queued_exists ? "queued_steps" : "no_work") }
      end

      result || { enqueue: false, lead_run_id: @lead_run_id, status: "unknown", reason: "missing_run" }
    end
  end
end
