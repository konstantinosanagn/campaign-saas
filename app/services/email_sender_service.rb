class EmailSenderService
  require "resolv"

  ####################################################################
  # PUBLIC ENTRY — Send email for a lead
  ####################################################################
  def self.send_email_for_lead(lead)
    user = lead.campaign.user

    from_email = user.send_from_email.presence || user.email
    subject    = "Message from #{user.email}"
    html       = get_body_for_lead(lead)

    configure_smtp!(user, from_email)

    LeadMailer.with(
      to:       lead.email,
      from:     from_email,
      subject:  subject,
      body:     html
    ).outreach_email.deliver_now

    { success: true, message: "Email sent to #{lead.email}" }

  rescue => e
    Rails.logger.error("[EmailSender] FAILED: #{e.message}")
    { success: false, error: e.message }
  end

  ####################################################################
  # Pick body: DESIGN → WRITER → ERROR
  ####################################################################
  def self.get_body_for_lead(lead)
    design = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_DESIGN)
    writer = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)

    return design.output_data["formatted_email"] if design&.output_data&.dig("formatted_email").present?
    return writer.output_data["email"] if writer&.output_data&.dig("email").present?

    raise "No email content available for this lead"
  end

  ####################################################################
  # MAIN SMTP CONFIGURATION LOGIC
  ####################################################################
  def self.configure_smtp!(user, from_email)
    domain = from_email.split("@").last.downcase

    ###########################################
    # 1️⃣ USER STORED SMTP CREDENTIALS (app password)
    ###########################################
    if user.smtp_app_password.present? && user.smtp_username.present? && user.smtp_server.present?
      Rails.logger.info("[SMTP] Using USER SMTP settings")

      ActionMailer::Base.smtp_settings = {
        address: user.smtp_server,
        port:    user.smtp_port || 587,
        domain:  domain,
        user_name: user.smtp_username,
        password:  user.smtp_app_password,
        authentication: :plain,
        enable_starttls_auto: true,
        openssl_verify_mode: Rails.env.development? ? "none" : nil
      }

      Rails.logger.info("[SMTP] FINAL USER SMTP = #{ActionMailer::Base.smtp_settings.inspect}")
      return :smtp_user
    end

    ###########################################
    # 2️⃣ AUTO-KNOWN PROVIDERS (gmail/outlook/yahoo/etc)
    ###########################################
    if AgentConstants::AUTO_KNOWN_PROVIDERS.key?(domain)
      provider = AgentConstants::AUTO_KNOWN_PROVIDERS[domain]

      Rails.logger.info("[SMTP] Using AUTO PROVIDER #{provider[:address]}")

      ActionMailer::Base.smtp_settings = {
        address: provider[:address],
        port:    provider[:port],
        domain:  domain,
        user_name: from_email,
        password:  user.smtp_app_password, # if nil → SMTP-AUTH fails
        authentication: :plain,
        enable_starttls_auto: true,
        openssl_verify_mode: Rails.env.development? ? "none" : nil
      }

      Rails.logger.info("[SMTP] FINAL PROVIDER SMTP = #{ActionMailer::Base.smtp_settings.inspect}")
      return :smtp_known
    end

    ###########################################
    # 3️⃣ FALLBACK (smtp.domain.com)
    ###########################################
    fallback = "smtp.#{domain}"
    Rails.logger.info("[SMTP] Using FALLBACK #{fallback}")

    ActionMailer::Base.smtp_settings = {
      address: fallback,
      port: 587,
      domain: domain,
      user_name: from_email,
      password: user.smtp_app_password,
      authentication: :plain,
      enable_starttls_auto: true,
      openssl_verify_mode: Rails.env.development? ? "none" : nil
    }

    Rails.logger.info("[SMTP] FINAL FALLBACK SMTP = #{ActionMailer::Base.smtp_settings.inspect}")
    :smtp_fallback
  end
end
