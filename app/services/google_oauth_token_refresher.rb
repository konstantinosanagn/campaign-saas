# app/services/google_oauth_token_refresher.rb
require "faraday"
require "json"
require_relative "../exceptions/gmail_authorization_error"

class GoogleOauthTokenRefresher
  TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token".freeze

  # Public: ensure the user's Gmail access token is fresh.
  # Returns the user (possibly updated).
  def self.refresh!(user)
    return user unless needs_refresh?(user)

    response = Faraday.post(TOKEN_ENDPOINT) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        client_id:     ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        grant_type:    "refresh_token",
        refresh_token: user.gmail_refresh_token
      )
    end

    unless response.success?
      Rails.logger.error("[GoogleOauthTokenRefresher] Refresh failed: #{response.status} #{response.body}")

      # Check if this is an authorization error (401, 403, or invalid_grant)
      if [ 401, 403 ].include?(response.status) || response.body.to_s.include?("invalid_grant")
        raise GmailAuthorizationError.new(
          "Gmail access token has been revoked or is invalid. Please reconnect your Gmail account.",
          status_code: response.status,
          response_body: response.body
        )
      end

      raise "Google token refresh failed (status #{response.status})"
    end

    data = JSON.parse(response.body)

    user.update!(
      gmail_access_token:     data.fetch("access_token"),
      gmail_token_expires_at: Time.current + data.fetch("expires_in", 3600).to_i.seconds
    )

    user
  end

  def self.needs_refresh?(user)
    return false if user.gmail_refresh_token.blank? # nothing to refresh
    return true  if user.gmail_access_token.blank?
    return true  if user.gmail_token_expires_at.blank?

    # Refresh if token will expire in the next 5 minutes
    user.gmail_token_expires_at < 5.minutes.from_now
  end
end
