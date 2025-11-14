##
# GmailOauthService
#
# Service responsible for managing Gmail OAuth tokens and authentication
# for sending emails via Gmail/Google Workspace SMTP with OAuth2.
#
# Usage:
#   # Get authorization URL for user
#   GmailOauthService.authorization_url(user)
#
#   # Exchange authorization code for tokens
#   GmailOauthService.exchange_code_for_tokens(user, code)
#
#   # Get valid access token (refreshes if needed)
#   GmailOauthService.valid_access_token(user)
#
class GmailOauthService
  class << self
    def authorization_url(user)
      client = build_authorization_client
      uri = client.authorization_uri
      Rails.logger.info("Gmail OAuth authorization URL generated: #{uri}")
      uri.to_s
    end

    def exchange_code_for_tokens(user, code)
      client = build_authorization_client
      client.code = code

      begin
        client.fetch_access_token!

        expires_at =
          if client.expires_at
            Time.at(client.expires_at.to_i)
          elsif client.expires_in
            Time.current + client.expires_in.seconds
          else
            Time.current + 1.hour
          end

        update_params = {
          gmail_access_token: client.access_token,
          gmail_token_expires_at: expires_at
        }

        if client.refresh_token.present?
          update_params[:gmail_refresh_token] = client.refresh_token
        end

        user.update!(update_params)

        Rails.logger.info("[Gmail OAuth] Tokens saved for user #{user.id}, expires at #{expires_at}")
        true
      rescue => e
        Rails.logger.error("[Gmail OAuth] Failed to exchange code: #{e.class} #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        false
      end
    end

    def valid_access_token(user)
      # Use existing token if not expired
      if user.gmail_access_token.present? &&
         user.gmail_token_expires_at.present? &&
         user.gmail_token_expires_at > 5.minutes.from_now
        return user.gmail_access_token
      end

      # Cannot refresh without refresh token
      return nil unless user.gmail_refresh_token.present?

      # Refresh and return updated token
      refresh_access_token(user)
      user.gmail_access_token
    end

    def refresh_access_token(user)
      return false unless user.gmail_refresh_token.present?

      client = build_refresh_client(user)

      begin
        client.refresh!

        expires_at =
          if client.expires_at
            Time.at(client.expires_at.to_i)
          elsif client.expires_in
            Time.current + client.expires_in.seconds
          else
            Time.current + 1.hour
          end

        user.update!(
          gmail_access_token: client.access_token,
          gmail_token_expires_at: expires_at
        )

        Rails.logger.info("[Gmail OAuth] Token refreshed for user #{user.id}, expires at #{expires_at}")
        true
      rescue => e
        Rails.logger.error("[Gmail OAuth] Failed to refresh token for user #{user.id}: #{e.class} #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        false
      end
    end

    def oauth_configured?(user)
      token = valid_access_token(user)
      configured = token.present?
      refresh_present = user.gmail_refresh_token.present?

      Rails.logger.info(
        "[GmailOauth] oauth_configured? check for user #{user.id}: " \
        "token_present=#{configured}, refresh_token_present=#{refresh_present}"
      )

      configured
    end

    private

    def build_authorization_client
      client_id = ENV["GMAIL_CLIENT_ID"]
      client_secret = ENV["GMAIL_CLIENT_SECRET"]

      unless client_id.present? && client_secret.present?
        raise "Gmail OAuth not configured. Please set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET."
      end

      redirect_uri =
        if ENV["GMAIL_REDIRECT_URI"].present?
          ENV["GMAIL_REDIRECT_URI"]
        else
          base_url = ENV.fetch("MAILER_HOST", "localhost:3000")
          base_url = "http://#{base_url}" unless base_url.start_with?("http")
          "#{base_url}/oauth/gmail/callback"
        end

      Rails.logger.info("[Gmail OAuth] Using redirect_uri: #{redirect_uri}")

      Signet::OAuth2::Client.new(
        authorization_uri: "https://accounts.google.com/o/oauth2/auth",
        token_credential_uri: "https://oauth2.googleapis.com/token",
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        scope: "https://www.googleapis.com/auth/gmail.send",
        access_type: "offline",
        prompt: "consent"
      )
    end

    def build_refresh_client(user)
      client_id = ENV["GMAIL_CLIENT_ID"]
      client_secret = ENV["GMAIL_CLIENT_SECRET"]

      unless client_id.present? && client_secret.present?
        raise "Gmail OAuth not configured. Please set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET."
      end

      Signet::OAuth2::Client.new(
        token_credential_uri: "https://oauth2.googleapis.com/token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: user.gmail_refresh_token
      )
    end
  end
end
