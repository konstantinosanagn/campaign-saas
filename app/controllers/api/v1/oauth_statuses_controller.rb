module Api
  module V1
    class OauthStatusesController < BaseController
      ##
      # GET /api/v1/oauth_status
      # Returns OAuth configuration status
      def show
        client_id_present = ENV["GMAIL_CLIENT_ID"].present?
        client_secret_present = ENV["GMAIL_CLIENT_SECRET"].present?
        oauth_configured = client_id_present && client_secret_present

        # Log for debugging (avoid logging sensitive values)
        Rails.logger.info("OAuth Status Check - CLIENT_ID present: #{client_id_present}, CLIENT_SECRET present: #{client_secret_present}")

        status = {
          oauth_configured: oauth_configured,
          client_id_set: client_id_present,
          client_secret_set: client_secret_present,
          message: oauth_configured ? "OAuth is configured" : "OAuth is not configured. Missing: #{[!client_id_present && 'GMAIL_CLIENT_ID', !client_secret_present && 'GMAIL_CLIENT_SECRET'].compact.join(', ')}"
        }

        render json: status
      end
    end
  end
end
