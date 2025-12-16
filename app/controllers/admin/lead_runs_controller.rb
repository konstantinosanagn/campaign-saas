module Admin
  class LeadRunsController < BaseController
    # GET /admin/lead_runs/:id
    def show
      run = LeadRun.includes(:steps, :lead, :campaign).find(params[:id])

      payload = {
        id: run.id,
        status: run.status,
        lead_id: run.lead_id,
        campaign_id: run.campaign_id,
        rewrite_count: run.rewrite_count,
        min_score: run.min_score,
        max_rewrites: run.max_rewrites,
        started_at: run.started_at,
        finished_at: run.finished_at,

        # Dangerous blob: never show raw values (even to admins).
        config_snapshot: "[REDACTED]",
        config_snapshot_present: run.config_snapshot.present?,
        config_snapshot_keys: run.config_snapshot.is_a?(Hash) ? run.config_snapshot.keys : nil,

        steps: run.steps.map { |s|
          {
            id: s.id,
            position: s.position,
            agent_name: s.agent_name,
            status: s.status,
            step_started_at: s.step_started_at,
            step_finished_at: s.step_finished_at,
            agent_output_id: s.agent_output_id,
            meta: AdminRedactor.redact_hash(s.meta || {})
          }
        }
      }

      render json: AdminRedactor.redact_hash(payload)
    end
  end
end
