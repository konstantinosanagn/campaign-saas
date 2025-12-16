##
# EmailDeliveryConfig
#
# Shared service for checking email delivery configuration.
# Prevents logic divergence across planner, executor, and controller.
#
# Usage:
#   result = EmailDeliveryConfig.check(user: user, campaign: campaign)
#   if result[:ok]
#     # Sending is configured
#   else
#     # Check result[:reasons] for actionable guidance
#   end
#
class EmailDeliveryConfig
  ##
  # Checks if email delivery is configured for a user/campaign
  #
  # @param user [User] The user to check
  # @param campaign [Campaign, nil] Optional campaign (currently unused but kept for API consistency)
  # @return [Hash] { ok: Boolean, reasons: Hash }
  def self.check(user:, campaign: nil)
    return { ok: false, reasons: { user: "missing" } } unless user

    reasons = {}

    # Check 1: User Gmail OAuth
    user_gmail_ok = if user.can_send_gmail?
      reasons["user_gmail_oauth"] = "configured"
      true
    else
      missing = []
      missing << "missing_refresh_token" unless user.gmail_refresh_token.present?
      missing << "missing_access_token" unless user.gmail_access_token.present?
      missing << "missing_email" unless user.gmail_email.present?
      reasons["user_gmail_oauth"] = missing.any? ? missing.first : "not_configured"
      false
    end

    return { ok: true, reasons: reasons } if user_gmail_ok

    # Check 2: Default Gmail sender
    default_sender_email = ENV["DEFAULT_GMAIL_SENDER"]
    if default_sender_email.present?
      default_sender = User.find_by(email: default_sender_email)
      if default_sender&.can_send_gmail?
        reasons["default_sender"] = "configured"
        return { ok: true, reasons: reasons }
      else
        reasons["default_sender"] = default_sender ? "not_configured" : "not_found"
      end
    else
      reasons["default_sender"] = "not_set"
    end

    # Check 3: From email Gmail OAuth
    from_email = user.send_from_email.presence || user.email
    if from_email.to_s.include?("@gmail.com") || from_email.to_s.include?("@googlemail.com")
      oauth_user = User.find_by(email: from_email)
      if oauth_user
        oauth_configured = GmailOauthService.oauth_configured?(oauth_user)
        reasons["from_email_oauth"] = oauth_configured ? "configured" : "not_configured"
        return { ok: true, reasons: reasons } if oauth_configured
      else
        reasons["from_email_oauth"] = "user_not_found"
      end
    else
      reasons["from_email_oauth"] = "not_gmail"
    end

    # Check 4: SMTP fallback
    smtp_address = ENV["SMTP_ADDRESS"]
    smtp_password = ENV["SMTP_PASSWORD"]
    if smtp_address.present? && smtp_password.present?
      reasons["smtp"] = "configured"
      return { ok: true, reasons: reasons }
    else
      missing = []
      missing << "missing_address" unless smtp_address.present?
      missing << "missing_password" unless smtp_password.present?
      reasons["smtp"] = missing.any? ? missing.first : "not_configured"
    end

    { ok: false, reasons: reasons }
  end
end


