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
    ##
    # Returns the authorization URL for OAuth flow
    #
    # @param user [User] The user requesting authorization
    # @return [String] Authorization URL
    def authorization_url(user)
      client = build_authorization_client
      uri = client.authorization_uri
      Rails.logger.info("Gmail OAuth authorization URL generated: #{uri}")
      uri.to_s
    end

    ##
    # Exchanges authorization code for access and refresh tokens
    #
    # @param user [User] The user to store tokens for
    # @param code [String] Authorization code from OAuth callback
    # @return [Boolean] True if successful
    def exchange_code_for_tokens(user, code)
      client = build_authorization_client
      client.code = code

      begin
        client.fetch_access_token!

        # Calculate expiration time (expires_at is in seconds since epoch)
        expires_at = if client.expires_at
          Time.at(client.expires_at.to_i)
        elsif client.expires_in
          Time.current + client.expires_in.seconds
        else
          # Default to 1 hour if not specified
          Time.current + 1.hour
        end

        update_params = {
          gmail_access_token: client.access_token,
          gmail_token_expires_at: expires_at
        }

        # Only update refresh_token if we got one (it's only returned on first authorization)
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

    ##
    # Gets a valid access token, refreshing if necessary
    #
    # @param user [User] The user to get token for
    # @return [String, nil] Access token or nil if unavailable
    def valid_access_token(user)
      return nil unless user.gmail_refresh_token.present?

      # Check if token is expired or about to expire (within 5 minutes)
      if user.gmail_token_expires_at.nil? || user.gmail_token_expires_at < 5.minutes.from_now
        refresh_access_token(user)
      end

      user.gmail_access_token
    end

    ##
    # Refreshes the access token using refresh token
    #
    # @param user [User] The user to refresh token for
    # @return [Boolean] True if successful
    def refresh_access_token(user)
      return false unless user.gmail_refresh_token.present?

      client = build_refresh_client(user)

      begin
        client.refresh!

        # Calculate expiration time
        expires_at = if client.expires_at
          Time.at(client.expires_at.to_i)
        elsif client.expires_in
          Time.current + client.expires_in.seconds
        else
          # Default to 1 hour if not specified
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

    ##
    # Checks if user has valid OAuth credentials
    #
    # @param user [User] The user to check
    # @return [Boolean] True if user has valid OAuth setup
    def oauth_configured?(user)
      refresh_token_present = user.gmail_refresh_token.present?
      access_token_result = valid_access_token(user)
      access_token_present = access_token_result.present?
      
      Rails.logger.info("[GmailOauth] oauth_configured? check for user #{user.id}: refresh_token=#{refresh_token_present}, access_token=#{access_token_present}")
      
      refresh_token_present && access_token_present
    end

    private

    ##
    # Builds OAuth client for authorization flow
    def build_authorization_client
      client_id = ENV["GMAIL_CLIENT_ID"]
      client_secret = ENV["GMAIL_CLIENT_SECRET"]

      unless client_id.present? && client_secret.present?
        raise "Gmail OAuth not configured. Please set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET environment variables."
      end

      # Construct redirect URI - must match exactly what's in Google Console
      # Priority: 1) GMAIL_REDIRECT_URI env var, 2) Construct from MAILER_HOST, 3) Default to localhost
      redirect_uri = if ENV["GMAIL_REDIRECT_URI"].present?
        ENV["GMAIL_REDIRECT_URI"]
      else
        base_url = ENV.fetch("MAILER_HOST", "localhost:3000")
        # Ensure protocol is included
        base_url = "http://#{base_url}" unless base_url.start_with?("http")
        "#{base_url}/oauth/gmail/callback"
      end

      Rails.logger.info("[Gmail OAuth] Using redirect_uri: #{redirect_uri}")

      client = Signet::OAuth2::Client.new(
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

    ##
    # Builds OAuth client for token refresh
    def build_refresh_client(user)
      client_id = ENV["GMAIL_CLIENT_ID"]
      client_secret = ENV["GMAIL_CLIENT_SECRET"]

      unless client_id.present? && client_secret.present?
        raise "Gmail OAuth not configured. Please set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET environment variables."
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
