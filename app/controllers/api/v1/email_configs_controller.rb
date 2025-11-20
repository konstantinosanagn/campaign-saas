module Api
  module V1
    class EmailConfigsController < BaseController

      def show
        user = current_user
        from = user.send_from_email || user.email
        domain = from.split("@").last.downcase

        provider_key = AgentConstants::DETAILED_2FA_INSTRUCTIONS[domain]
        details = nil

        if provider_key.is_a?(Symbol)
          details = AgentConstants::DETAILED_2FA_INSTRUCTIONS.detect { |k, v| k == provider_key }.last
        elsif provider_key.is_a?(Hash)
          details = provider_key
        end

        render json: {
          email: from,
          smtp_server: user.smtp_server,
          smtp_port: user.smtp_port,
          smtp_username: user.smtp_username,
          has_app_password: user.smtp_app_password.present?,
          requires_2fa: details.present?,
          instructions: details
        }
      end

      # def show
      #   user = current_user
      #   from = user.send_from_email || user.email
      #   domain = from.split("@").last.downcase

      #   provider_link = AgentConstants::APP_PASSWORD_PROVIDERS[domain]
      #   requires_2fa  = provider_link.present?

      #   render json: {
      #     email: from,
      #     smtp_server: user.smtp_server,
      #     smtp_port: user.smtp_port,
      #     smtp_username: user.smtp_username,
      #     has_app_password: user.smtp_app_password.present?,
      #     requires_2fa: requires_2fa,
      #     app_password_link: provider_link
      #   }
      # end

      def update
        user = current_user

        # read raw params, not nested email_config
        raw = params.permit(:email, :app_password)

        updates = {
          send_from_email:   raw[:email],
          smtp_username:     raw[:email],
          smtp_server:       nil,
          smtp_port:         nil,
          smtp_app_password: raw[:app_password]
        }

        if user.update(updates)
          render json: { success: true }
        else
          render json: { success: false, errors: user.errors.full_messages }
        end
      end
    end
  end
end
