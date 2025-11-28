SMTP_2FA_REQUIRED = %w[
  gmail.com
  googlemail.com
  yahoo.com
  outlook.com
  hotmail.com
  live.com
  zoho.com
  icloud.com
].freeze

SMTP_APP_PASSWORD_LINKS = {
  "gmail.com"        => "https://myaccount.google.com/apppasswords",
  "googlemail.com"   => "https://myaccount.google.com/apppasswords",
  "yahoo.com"        => "https://login.yahoo.com/account/security",
  "outlook.com"      => "https://mysignins.microsoft.com/security-info",
  "hotmail.com"      => "https://mysignins.microsoft.com/security-info",
  "live.com"         => "https://mysignins.microsoft.com/security-info",
  "zoho.com"         => "https://accounts.zoho.com/u/h/security/apppasswords",
  "icloud.com"       => "https://appleid.apple.com/account/manage"
}.freeze
