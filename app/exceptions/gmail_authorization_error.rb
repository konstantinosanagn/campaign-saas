##
# GmailAuthorizationError
#
# Raised when Gmail OAuth tokens are invalid, expired, or revoked.
# This indicates the user needs to reconnect their Gmail account.
#
class GmailAuthorizationError < StandardError
  attr_reader :status_code, :response_body

  def initialize(message = "Gmail authorization failed", status_code: nil, response_body: nil)
    super(message)
    @status_code = status_code
    @response_body = response_body
  end
end
