module Api
  module V1
    class EmailConfigsController < BaseController
      ##
      # GET /api/v1/email_config
      # Returns current user's email configuration
      def show
        send_from_email = current_user.send_from_email.presence || current_user.email

        # Check OAuth for current user
        oauth_configured = false
        begin
          oauth_configured = GmailOauthService.oauth_configured?(current_user)

          # If send_from_email is different and current user doesn't have OAuth,
          # check if the send_from_email user has OAuth
          if !oauth_configured && send_from_email != current_user.email
            email_user = User.find_by(email: send_from_email)
            if email_user
              oauth_configured = GmailOauthService.oauth_configured?(email_user)
              Rails.logger.info("[EmailConfig] Using OAuth from send_from_email user (#{email_user.id})")
            end
          end
        rescue => e
          # If OAuth is not configured at app level, return false
          Rails.logger.warn("Gmail OAuth service error: #{e.message}")
          oauth_configured = false
        end

        render json: {
          email: send_from_email,
          oauth_configured: oauth_configured
        }
      end

      ##
      # PUT /api/v1/email_config
      # Updates user's send from email address
      def update
        email = params[:email]&.strip
        if email.present?
          if current_user.update(send_from_email: email)
            send_from_email = current_user.send_from_email.presence || current_user.email

            # Check OAuth for current user or send_from_email user
            oauth_configured = false
            begin
              oauth_configured = GmailOauthService.oauth_configured?(current_user)

              # If send_from_email is different and current user doesn't have OAuth,
              # check if the send_from_email user has OAuth
              if !oauth_configured && send_from_email != current_user.email
                email_user = User.find_by(email: send_from_email)
                if email_user
                  oauth_configured = GmailOauthService.oauth_configured?(email_user)
                  Rails.logger.info("[EmailConfig] Using OAuth from send_from_email user (#{email_user.id})")
                end
              end
            rescue => e
              Rails.logger.warn("Gmail OAuth service error: #{e.message}")
              oauth_configured = false
            end

            render json: {
              email: send_from_email,
              oauth_configured: oauth_configured
            }
          else
            render json: {
              error: current_user.errors.full_messages.join(", ")
            }, status: :unprocessable_entity
          end
        else
          render json: {
            error: "Email is required"
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
