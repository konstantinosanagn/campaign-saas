module ApplicationHelper
  ##
  # Returns a badge text indicating Gmail connection status
  # @param user [User] The user to check
  # @return [String] Status message with email if connected
  def gmail_status_badge(user)
    if user.respond_to?(:can_send_gmail?) && user.can_send_gmail?
      email = user.respond_to?(:gmail_email) ? user.gmail_email : nil
      if email.present?
        "Gmail connected (#{email})"
      else
        "Gmail connected"
      end
    else
      "Gmail not connected"
    end
  end

  ##
  # Checks if default Gmail sender is available and configured
  # @return [Boolean] True if default sender exists and has Gmail OAuth configured
  def default_gmail_sender_available?
    default_sender_email = ENV["DEFAULT_GMAIL_SENDER"]
    return false unless default_sender_email.present?
    
    default_sender = User.find_by(email: default_sender_email)
    default_sender&.can_send_gmail? || false
  end

  ##
  # Returns the default Gmail sender email address
  # @return [String, nil] The default sender email or nil if not configured
  def default_gmail_sender_email
    ENV["DEFAULT_GMAIL_SENDER"]
  end
end
