class EmailSenderService
  require "resolv"

  # PUBLIC ENTRY — Send email for a lead
  def self.send_email_for_lead(lead)
    user = lead.campaign.user

    from_email = user.send_from_email.presence || user.email
    raw_body   = personalize_sender_name(get_body_for_lead(lead), user)
    subject, html = extract_subject_and_body(raw_body)
    subject ||= "Message from #{from_email}"

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

  # Pick body: DESIGN → WRITER → ERROR
  def self.get_body_for_lead(lead)
    design = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_DESIGN)
    writer = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)

    if design&.output_data&.dig("formatted_email").present?
      return normalize_email_content(design.output_data["formatted_email"])
    end

    return writer.output_data["email"] if writer&.output_data&.dig("email").present?

    raise "No email content available for this lead"
  end

  def self.extract_subject_and_body(email_content)
    return [nil, email_content] if email_content.blank?

    lines = email_content.to_s.lines
    subject_index = lines.find_index { |line| line.strip.downcase.start_with?("subject:") }
    return [nil, email_content] if subject_index.nil?

    subject_line = lines.delete_at(subject_index)
    subject = subject_line.split(":", 2).last.to_s.strip
    body = lines.join.lstrip
    [subject.presence, body]
  end

  # MAIN SMTP CONFIGURATION LOGIC
  def self.configure_smtp!(user, from_email)
    domain = from_email.split("@").last.downcase

    # USER STORED SMTP CREDENTIALS (app password)
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

    # AUTO-KNOWN PROVIDERS (gmail/outlook/yahoo/etc)
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

    # FALLBACK (smtp.domain.com)
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

  def self.normalize_email_content(content)
    return content if content.blank?

    primary = content.split(/\n\s*---\s*\n/).first || content
    primary.sub(/\A\s*\*\*Variant.*?\*\*\s*\n/i, "").lstrip
  end

  def self.personalize_sender_name(content, user)
    return content if content.blank?

    replacement = sender_display_name(user)
    return content if replacement.blank?

    content.to_s.gsub("[Your Name]", replacement)
  end

  def self.sender_display_name(user)
    candidate_user = sender_identity_user(user)

    [
      preferred_name(candidate_user),
      candidate_user&.send_from_email.presence,
      candidate_user&.email
    ].find { |value| value.present? }
  end

  def self.preferred_name(user)
    return nil unless user

    [user.first_name, user.last_name].compact.join(" ").presence ||
      user.name.presence
  end

  def self.sender_identity_user(user)
    return user if user.send_from_email.blank?

    return user if user.send_from_email.casecmp(user.email).zero?

    User.find_by(email: user.send_from_email) || user
  end
end
