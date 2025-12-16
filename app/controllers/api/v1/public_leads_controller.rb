##
# PublicLeadsController
#
# Public demo endpoint for sending emails. Does not require Devise authentication,
# but requires a demo token in the X-Demo-Token header.
#
# Usage:
#   curl -X POST "http://localhost:3000/api/v1/public/leads/86/send_email" \
#     -H "X-Demo-Token: <DEMO_SEND_TOKEN>" \
#     -H "Accept: application/json"
#
module Api
  module V1
    class PublicLeadsController < ActionController::API
      before_action :require_demo_token!
      before_action :set_json_format

      ##
      # POST /api/v1/public/leads/:id/send_email
      # Sends email for a lead using the DEFAULT_SENDER_EMAIL user
      def send_email
        lead = Lead.find_by(id: params[:id])

        unless lead
          render json: { error: "Lead not found" }, status: :not_found
          return
        end

        # Get the default sender user from env
        default_sender_email = ENV["DEFAULT_SENDER_EMAIL"]
        unless default_sender_email.present?
          render json: { error: "DEFAULT_SENDER_EMAIL not configured" }, status: :internal_server_error
          return
        end

        sender_user = User.find_by(email: default_sender_email)
        unless sender_user
          render json: { error: "Default sender user not found" }, status: :internal_server_error
          return
        end

        # Security: Only allow sending for leads in campaigns owned by the sender user
        # This prevents arbitrary lead ID guessing attacks
        unless lead.campaign.user_id == sender_user.id
          render json: { error: "Lead not authorized for demo sending" }, status: :forbidden
          return
        end

        begin
          # Use ensure_sendable_run! with the sender user for config checks
          run = LeadRuns.ensure_sendable_run!(
            lead: lead,
            requested_agent_name: AgentConstants::AGENT_SENDER,
            sender_user: sender_user
          )

          # Enqueue the job
          job = AgentExecutionJob.perform_later(
            { lead_run_id: run.id, requested_agent_name: AgentConstants::AGENT_SENDER }
          )

          render json: {
            success: true,
            message: "Email sending queued",
            status: "queued",
            jobId: job.job_id
          }, status: :accepted

        rescue LeadRuns::RunInProgressError => e
          render json: {
            success: false,
            error: "run_in_progress",
            runId: e.run_id,
            nextAgent: e.next_agent
          }, status: :unprocessable_entity

        rescue LeadRuns::SenderNotPlannedError => e
          render json: {
            success: false,
            error: "sender_not_planned",
            reason: e.reason
          }, status: :unprocessable_entity

        rescue LeadRuns::SendingNotConfiguredError => e
          render json: {
            success: false,
            error: "sending_not_configured",
            reasons: e.reasons
          }, status: :unprocessable_entity

        rescue LeadRuns::AlreadySendingError => e
          render json: {
            success: false,
            error: "already_sending",
            stepId: e.step_id,
            runId: e.run_id
          }, status: :unprocessable_entity

        rescue LeadRunPlanner::PlannerError => e
          render json: {
            success: false,
            error: e.message
          }, status: :unprocessable_entity

        rescue => e
          Rails.logger.error("[PublicLeadsController#send_email] Error: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
      end

      private

      ##
      # Validates the demo token from the X-Demo-Token header
      def require_demo_token!
        token = request.headers["X-Demo-Token"].to_s
        expected_token = ENV["DEMO_SEND_TOKEN"]

        unless expected_token.present?
          render json: { error: "DEMO_SEND_TOKEN not configured" }, status: :internal_server_error
          return
        end

        unless ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
          render json: { error: "Invalid demo token" }, status: :unauthorized
        end
      end

      ##
      # Force JSON format for API requests
      def set_json_format
        request.format = :json if request.path.start_with?("/api/")
      end
    end
  end
end


