# app/services/gmail_sender.rb
require "faraday"
require "json"
require "base64"
require "securerandom"
require_relative "../exceptions/gmail_authorization_error"

class GmailSender
  GMAIL_SEND_ENDPOINT = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send".freeze

  # Usage:
  #   GmailSender.send_email(
  #     user: current_user,
  #     to: "lead@example.com",
  #     subject: "Hello",
  #     text_body: "Plain text",
  #     html_body: "<p>HTML version</p>" # optional
  #   )
  def self.send_email(user:, to:, subject:, text_body:, html_body: nil)
    GoogleOauthTokenRefresher.refresh!(user)

    Rails.logger.info(
      "[GmailSender] Sending email user_id=#{user.id} to=#{to} subject=#{subject.truncate(50)} via Gmail API"
    )

    raw_message     = build_raw_message(
      from:      user.gmail_email,
      to:        to,
      subject:   subject,
      text_body: text_body,
      html_body: html_body
    )
    encoded_message = Base64.urlsafe_encode64(raw_message)

    response = Faraday.post(GMAIL_SEND_ENDPOINT) do |req|
      req.headers["Authorization"] = "Bearer #{user.gmail_access_token}"
      req.headers["Content-Type"]  = "application/json"
      req.body = { raw: encoded_message }.to_json
    end

    unless response.success?
      Rails.logger.error("[GmailSender] Send failed: #{response.status} #{response.body}")

      # Check if this is an authorization error (401, 403)
      if [ 401, 403 ].include?(response.status)
        raise GmailAuthorizationError.new(
          "Gmail access token has been revoked or is invalid. Please reconnect your Gmail account.",
          status_code: response.status,
          response_body: response.body
        )
      end

      raise "Gmail send failed (status #{response.status})"
    end

    JSON.parse(response.body) # returns Gmail message resource
  end

  # Build an RFC822 email for Gmail API
  def self.build_raw_message(from:, to:, subject:, text_body:, html_body:)
    if html_body.present?
      boundary = "boundary_#{SecureRandom.hex(16)}"
      <<~MESSAGE
        From: #{from}
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: multipart/alternative; boundary=#{boundary}

        --#{boundary}
        Content-Type: text/plain; charset=UTF-8

        #{text_body}

        --#{boundary}
        Content-Type: text/html; charset=UTF-8

        #{html_body}

        --#{boundary}--
      MESSAGE
    else
      <<~MESSAGE
        From: #{from}
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: text/plain; charset=UTF-8

        #{text_body}
      MESSAGE
    end
  end
end
