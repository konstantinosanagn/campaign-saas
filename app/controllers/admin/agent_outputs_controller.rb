module Admin
  class AgentOutputsController < BaseController
    # GET /admin/agent_outputs
    #
    # Pagination is required to avoid accidental data exfiltration.
    # Use cursor-based pagination via ?after_id=...&limit=...
    def index
      limit = Integer(params.fetch(:limit, 50))
      limit = [ [ limit, 1 ].max, 200 ].min
      after_id = params[:after_id].present? ? params[:after_id].to_i : nil

      scope = AgentOutput.order(:id)
      scope = scope.where("id > ?", after_id) if after_id

      # Safe filters only (no SQL fragments)
      scope = scope.where(lead_id: params[:lead_id]) if params[:lead_id].present?
      scope = scope.where(lead_run_id: params[:lead_run_id]) if params[:lead_run_id].present?
      scope = scope.where(lead_run_step_id: params[:lead_run_step_id]) if params[:lead_run_step_id].present?
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(agent_name: params[:agent_name]) if params[:agent_name].present?

      rows = scope.limit(limit).to_a
      next_cursor = rows.last&.id

      payload = {
        count: rows.length,
        next_after_id: next_cursor,
        agent_outputs: rows.map { |o| serialize_agent_output(o) }
      }

      render json: AdminRedactor.redact_hash(payload)
    end

    # GET /admin/agent_outputs/:id
    def show
      output = AgentOutput.find(params[:id])
      render json: AdminRedactor.redact_hash(serialize_agent_output(output))
    end

    private

    def serialize_agent_output(o)
      {
        id: o.id,
        lead_id: o.lead_id,
        lead_run_id: o.lead_run_id,
        lead_run_step_id: o.lead_run_step_id,
        agent_name: o.agent_name,
        status: o.status,
        error_message: o.error_message,
        created_at: o.created_at,
        updated_at: o.updated_at,

        # Dangerous blob: never show raw values (even to admins).
        output_data: "[REDACTED]",
        output_data_present: o.output_data.present?,
        output_data_keys: o.output_data.is_a?(Hash) ? o.output_data.keys : nil
      }
    end
  end
end
