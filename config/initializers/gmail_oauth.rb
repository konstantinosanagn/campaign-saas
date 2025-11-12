##
# Gmail OAuth Configuration
#
# This initializer sets up Gmail OAuth for email sending.
# Required environment variables:
#   - GMAIL_CLIENT_ID: OAuth client ID from Google Cloud Console
#   - GMAIL_CLIENT_SECRET: OAuth client secret from Google Cloud Console
#   - GMAIL_REDIRECT_URI: OAuth redirect URI (defaults to /oauth/gmail/callback)
#
# To set up OAuth:
# 1. Go to https://console.cloud.google.com/
# 2. Create a new project or select existing one
# 3. Enable Gmail API
# 4. Create OAuth 2.0 credentials
# 5. Add authorized redirect URI: https://yourdomain.com/oauth/gmail/callback
# 6. Set environment variables with client ID and secret
#

if ENV["GMAIL_CLIENT_ID"].present? && ENV["GMAIL_CLIENT_SECRET"].present?
  Rails.logger.info "Gmail OAuth configured"
else
  Rails.logger.warn "Gmail OAuth not configured. Set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET to enable OAuth email sending."
end
