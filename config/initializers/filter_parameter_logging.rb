# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,

  # Explicit app secrets (belt-and-suspenders; we also enable
  # active_record.encryption.add_to_filter_parameters).
  :llm_api_key, :tavily_api_key,
  :llmApiKey, :tavilyApiKey,
  :gmail_access_token, :gmail_refresh_token, :gmail_token_expires_at,
  :gmailAccessToken, :gmailRefreshToken,

  # Common auth/credential keys that often appear in headers/params.
  :authorization, :api_key, :apiKey, :access_token, :refresh_token, :client_secret
]

# Belt-and-suspenders: ensure filtering catches camelCase keys even when parsed
# as strings (e.g. JSON payloads).
Rails.application.config.filter_parameters += [
  "llmApiKey", "tavilyApiKey", "gmailAccessToken", "gmailRefreshToken", "apiKey"
]
