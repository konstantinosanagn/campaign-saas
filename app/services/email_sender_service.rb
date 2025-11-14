##
# EmailSenderService
#
# Service responsible for sending emails to leads that have completed
# the agent processing pipeline (SEARCH → WRITER → CRITIQUE → DESIGN).
#
# Usage:
#   EmailSenderService.send_emails_for_campaign(campaign)
#   # Returns: { sent: 5, failed: 2, errors: [...] }
#
class EmailSenderService
  include AgentConstants
  class << self
    ##
    # Sends emails to all ready leads in a campaign
    # A lead is considered "ready" if it has completed the DESIGN agent
    # (or WRITER agent if DESIGN is disabled) and reached 'designed' or 'completed' stage
    #
    # @param campaign [Campaign] The campaign containing leads to send emails to
    # @return [Hash] Result with counts of sent/failed emails and any errors
    def send_emails_for_campaign(campaign)
      ready_leads = find_ready_leads(campaign)

      results = {
        sent: 0,
        failed: 0,
        errors: []
      }

      ready_leads.each do |lead|
        begin
          Rails.logger.info("[EmailSender] Attempting to send email to lead #{lead.id} (#{lead.email})")
          send_email_to_lead(lead)
          results[:sent] += 1
          Rails.logger.info("[EmailSender] Successfully sent email to lead #{lead.id}")
        rescue => e
          results[:failed] += 1
          results[:errors] << {
            lead_id: lead.id,
            lead_email: lead.email,
            error: e.message
          }
          Rails.logger.error("[EmailSender] Failed to send email to lead #{lead.id}: #{e.class} #{e.message}")
          Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        end
      end

      results
    end

    ##
    # Sends email to a single lead
    # This is a public method that can be called directly
    #
    # @param lead [Lead] The lead to send email to
    # @return [Hash] Result with success status and any error message
    def send_email_for_lead(lead)
      # Verify lead belongs to a campaign owned by a user
      unless lead.campaign&.user
        return {
          success: false,
          error: "Lead does not belong to a valid campaign"
        }
      end

      # Check if lead is ready
      unless lead_ready?(lead)
        return {
          success: false,
          error: "Lead is not ready to send. Lead must be at 'designed' or 'completed' stage with email content available."
        }
      end

      begin
        Rails.logger.info("[EmailSender] Attempting to send email to lead #{lead.id} (#{lead.email})")
        send_email_to_lead(lead)
        Rails.logger.info("[EmailSender] Successfully sent email to lead #{lead.id}")
        {
          success: true,
          message: "Email sent successfully to #{lead.email}"
        }
      rescue => e
        Rails.logger.error("[EmailSender] Failed to send email to lead #{lead.id}: #{e.class} #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        {
          success: false,
          error: e.message
        }
      end
    end

    ##
    # Checks if a lead is ready to have its email sent
    # A lead is ready if:
    # 1. It has reached 'designed' or 'completed' stage
    # 2. It has a completed DESIGN output (preferred) or WRITER output (fallback)
    #
    # @param lead [Lead] The lead to check
    # @return [Boolean] True if lead is ready to send
    def lead_ready?(lead)
      # Must be at designed or completed stage
      return false unless lead.stage.in?([ AgentConstants::STAGE_DESIGNED, AgentConstants::STAGE_COMPLETED ])

      # Check for DESIGN output first (preferred)
      design_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_DESIGN, status: AgentConstants::STATUS_COMPLETED)
      if design_output && design_output.output_data["formatted_email"].present?
        return true
      end

      # Fallback to WRITER output if DESIGN is not available
      writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED)
      if writer_output && writer_output.output_data["email"].present?
        return true
      end

      false
    end

    private

    ##
    # Finds all leads in a campaign that are ready to send
    def find_ready_leads(campaign)
      campaign.leads.select { |lead| lead_ready?(lead) }
    end

    ##
    # Sends email to a single lead
    def send_email_to_lead(lead)
      # Get the email content (prefer DESIGN formatted_email, fallback to WRITER email)
      design_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_DESIGN, status: AgentConstants::STATUS_COMPLETED)
      writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED)

      email_content = nil
      if design_output && design_output.output_data["formatted_email"].present?
        email_content = design_output.output_data["formatted_email"]
      elsif writer_output && writer_output.output_data["email"].present?
        email_content = writer_output.output_data["email"]
      end

      raise "No email content found for lead #{lead.id}" if email_content.blank?

      user = lead.campaign.user
      # Use configured send_from_email, fallback to user email, then default
      from_email = user&.send_from_email.presence || user&.email.presence || ApplicationMailer.default[:from]

      # 👉 Minimal change: use from_email to find OAuth user
      Rails.logger.info("[EmailSender] Using from_email: #{from_email}")
      Rails.logger.info("[EmailSender] Campaign owner: user #{user&.id} (#{user&.email}), send_from_email: #{user&.send_from_email}")
      oauth_user = User.find_by(email: from_email)
      Rails.logger.info("[EmailSender] OAuth user lookup: #{oauth_user&.id} (#{oauth_user&.email})")

      # Check OAuth configuration with detailed logging
      oauth_check_result = oauth_user ? GmailOauthService.oauth_configured?(oauth_user) : false
      Rails.logger.info("[EmailSender] OAuth check result: #{oauth_check_result} for user #{oauth_user&.id}")
      
      if oauth_user && oauth_check_result
        Rails.logger.info("[EmailSender] OAuth configured for oauth_user #{oauth_user.id}, getting access token...")
        Rails.logger.info("[EmailSender] User #{oauth_user.id} has refresh_token: #{oauth_user.gmail_refresh_token.present?}")
        access_token = GmailOauthService.valid_access_token(oauth_user)
        Rails.logger.info("[EmailSender] Access token present: #{access_token.present?}")
        if access_token
          Rails.logger.info("[EmailSender] Using Gmail API to send email (OAuth configured) as #{from_email}")
          send_via_gmail_api(lead, email_content, from_email, oauth_user, access_token)
          return
        else
          Rails.logger.warn("[EmailSender] OAuth configured but valid_access_token returned nil for user #{oauth_user.id}")
        end
      else
        if oauth_user.nil?
          Rails.logger.warn("[EmailSender] No user found with email: #{from_email}")
        else
          Rails.logger.warn("[EmailSender] OAuth NOT configured for from_email user (#{from_email}, user_id: #{oauth_user.id})")
        end
        # Check if this is a Gmail address that needs OAuth
        if from_email&.include?("@gmail.com") || from_email&.include?("@googlemail.com")
          if oauth_user.nil?
            error_msg = "No user account found for sending email address: #{from_email}. Please ensure this email address has a user account in the system."
          else
            error_msg = "Gmail OAuth is not configured for #{from_email}. Please log in as this user and complete Gmail OAuth authorization in Email Settings."
          end
          Rails.logger.error("[EmailSender] #{error_msg}")
          raise error_msg
        end
        Rails.logger.info("[EmailSender] Falling back to SMTP for non-Gmail address.")
      end

      # Fallback to SMTP (OAuth or password-based)
      configure_delivery_method(user) if user

      # Force SMTP delivery method (override development file delivery)
      ActionMailer::Base.delivery_method = :smtp
      ActionMailer::Base.perform_deliveries = true

      Rails.logger.info("[EmailSender] Pre-mail config - delivery_method: #{ActionMailer::Base.delivery_method}")
      Rails.logger.info("[EmailSender] Pre-mail config - smtp_settings address: #{ActionMailer::Base.smtp_settings[:address]}")

      # Send email using CampaignMailer
      mail = CampaignMailer.send_email(
        to: lead.email,
        recipient_name: lead.name,
        email_content: email_content,
        campaign_title: lead.campaign.title,
        from_email: from_email
      )

      # Final verification - delivery_method should still be :smtp
      if ActionMailer::Base.delivery_method != :smtp
        Rails.logger.error("[EmailSender] CRITICAL: Delivery method changed to #{ActionMailer::Base.delivery_method} after mail creation!")
        ActionMailer::Base.delivery_method = :smtp
        configure_delivery_method(user) if user
      end

      Rails.logger.info("[EmailSender] Mail object created, delivery_method: #{ActionMailer::Base.delivery_method}")
      Rails.logger.info("[EmailSender] SMTP address: #{ActionMailer::Base.smtp_settings[:address]}")
      Rails.logger.info("[EmailSender] SMTP user_name: #{ActionMailer::Base.smtp_settings[:user_name]}")

      begin
        Rails.logger.info("[EmailSender] Attempting to deliver mail via #{ActionMailer::Base.delivery_method}...")
        mail.deliver_now
        Rails.logger.info("[EmailSender] Mail delivered successfully via #{ActionMailer::Base.delivery_method}")
      rescue Net::SMTPAuthenticationError => e
        Rails.logger.error("[EmailSender] SMTP Authentication Error: #{e.class} - #{e.message}")
        Rails.logger.error("[EmailSender] Response code: #{e.response.code if e.respond_to?(:response)}")
        Rails.logger.error("[EmailSender] Response message: #{e.response.message if e.respond_to?(:response)}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        raise
      rescue Net::SMTPError => e
        Rails.logger.error("[EmailSender] SMTP Error: #{e.class} - #{e.message}")
        Rails.logger.error("[EmailSender] Response: #{e.response.inspect if e.respond_to?(:response)}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        raise
      rescue OpenSSL::SSL::SSLError => e
        Rails.logger.error("[EmailSender] SSL Error: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        raise
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Timeout::Error => e
        Rails.logger.error("[EmailSender] Connection Error: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        raise
      rescue => e
        Rails.logger.error("[EmailSender] Unexpected error delivering mail: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        raise
      end
    end

    ##
    # Sends email via Gmail API (more reliable than SMTP XOAUTH2)
    def send_via_gmail_api(lead, email_content, from_email, oauth_user, access_token)
      require "net/http"
      require "uri"
      require "base64"

      # Build email message in RFC 2822 format
      mail = CampaignMailer.send_email(
        to: lead.email,
        recipient_name: lead.name,
        email_content: email_content,
        campaign_title: lead.campaign.title,
        from_email: from_email
      )

      # Get the raw email content
      raw_email = mail.encoded

      # Encode to base64url (Gmail API requirement)
      raw_email_base64 = Base64.urlsafe_encode64(raw_email)

      # Send via Gmail API
      uri = URI("https://gmail.googleapis.com/gmail/v1/users/me/messages/send")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = { raw: raw_email_base64 }.to_json

      Rails.logger.info("[EmailSender] Sending email via Gmail API to #{lead.email}")
      response = http.request(request)

      if response.code == "200"
        Rails.logger.info("[EmailSender] Email sent successfully via Gmail API")
        result = JSON.parse(response.body)
        Rails.logger.info("[EmailSender] Gmail message ID: #{result['id']}")
      else
        error_body = response.body[0..500]
        Rails.logger.error("[EmailSender] Gmail API error: #{response.code} - #{error_body}")
        raise "Gmail API error: #{response.code} - #{error_body}"
      end
    rescue => e
      Rails.logger.error("[EmailSender] Gmail API send failed: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise
    end

    ##
    # Configures ActionMailer delivery method for OAuth2 or fallback to password
    def configure_delivery_method(user)
      Rails.logger.info("[EmailSender] Configuring delivery method for user #{user.id} (#{user.email})")

      # Determine which email will be used for sending
      send_from_email = user.send_from_email.presence || user.email
      Rails.logger.info("[EmailSender] Will send from: #{send_from_email}")

      # 👉 Minimal change: use send_from_email to find OAuth user
      oauth_user = User.find_by(email: send_from_email)
      Rails.logger.info("[EmailSender] SMTP OAuth user lookup: #{oauth_user&.id} (#{oauth_user&.email})")

      oauth_configured = oauth_user && GmailOauthService.oauth_configured?(oauth_user)
      Rails.logger.info("[EmailSender] OAuth configured for this from_email user: #{oauth_configured}")

      if oauth_configured
        access_token = GmailOauthService.valid_access_token(oauth_user)
        Rails.logger.info("[EmailSender] Access token available: #{access_token.present?}")

        if access_token
          ActionMailer::Base.delivery_method = :smtp
          smtp_settings = build_oauth2_smtp_settings(oauth_user, access_token, send_from_email)
          ActionMailer::Base.smtp_settings = smtp_settings
          # Force reload of mailer configuration
          ActionMailer::Base.perform_deliveries = true
          Rails.logger.info("[EmailSender] Configured OAuth2 SMTP with user: #{smtp_settings[:user_name]}")
          Rails.logger.info("[EmailSender] Delivery method set to: #{ActionMailer::Base.delivery_method}")
          Rails.logger.info("[EmailSender] Perform deliveries: #{ActionMailer::Base.perform_deliveries}")
          return
        else
          Rails.logger.warn("[EmailSender] OAuth configured but no valid access token available")
        end
      end

      # Fallback to password-based SMTP if configured
      if ENV["SMTP_ADDRESS"].present? && ENV["SMTP_PASSWORD"].present?
        ActionMailer::Base.delivery_method = :smtp
        ActionMailer::Base.smtp_settings = build_password_smtp_settings
        Rails.logger.info("[EmailSender] Configured password-based SMTP as fallback")
      else
        error_msg = "No email delivery method configured for #{send_from_email}. Gmail addresses require OAuth configuration. Please configure Gmail OAuth or set SMTP credentials."
        Rails.logger.error("[EmailSender] #{error_msg}")
        raise error_msg
      end
    end

    ##
    # Builds SMTP settings for OAuth2 authentication
    # Uses gmail_xoauth gem for OAuth2 support
    # @param user [User] The user whose OAuth token to use
    # @param access_token [String] The OAuth access token
    # @param send_from_email [String] The email address to send from (may differ from user.email)
    def build_oauth2_smtp_settings(user, access_token, send_from_email = nil)
      require "gmail_xoauth"

      # Use provided send_from_email, or user's send_from_email, or user email
      smtp_user = send_from_email || user.send_from_email.presence || user.email

      # The email in the OAuth string should match the email that was authorized
      # For Gmail, the token is tied to the authorized email, so we use user.email (the authorized email)
      oauth_email = user.email  # Use the email that was actually authorized

      # Generate XOAUTH2 string
      # Gmail XOAUTH2 format: user=email\1auth=Bearer token\1\1
      # Note: Use plain format (not Base64) - ActionMailer's Net::SMTP handles encoding
      oauth_string = "user=#{oauth_email}\x01auth=Bearer #{access_token}\x01\x01"

      Rails.logger.info("[EmailSender] Generated OAuth string for authorized email: #{oauth_email}, sending from: #{smtp_user}")
      Rails.logger.debug("[EmailSender] OAuth string length: #{oauth_string.length}")

      {
        address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
        port: ENV.fetch("SMTP_PORT", "587").to_i,
        domain: ENV.fetch("SMTP_DOMAIN", ENV.fetch("MAILER_HOST", "gmail.com")),
        user_name: smtp_user,  # This is the "from" email address
        password: oauth_string,  # OAuth string uses the authorized email
        authentication: :plain,   # Use plain auth, OAuth string is in password field
        enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true",
        # SSL/TLS settings for Gmail
        openssl_verify_mode: Rails.env.development? ? "none" : "peer",
        ssl: false,  # Use STARTTLS instead of direct SSL
        tls: true
      }
    end

    ##
    # Builds SMTP settings for password-based authentication
    def build_password_smtp_settings
      {
        address: ENV.fetch("SMTP_ADDRESS"),
        port: ENV.fetch("SMTP_PORT", "587").to_i,
        domain: ENV.fetch("SMTP_DOMAIN", ENV.fetch("MAILER_HOST", "example.com")),
        user_name: ENV.fetch("SMTP_USER_NAME"),
        password: ENV.fetch("SMTP_PASSWORD"),
        authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
        enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
      }
    end
  end
end
