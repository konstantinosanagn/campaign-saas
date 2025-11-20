##
# AgentConstants
#
# Centralized constants for agent names and statuses to avoid magic strings
# throughout the codebase.
#
module AgentConstants
  # Agent types
  AGENT_SEARCH = "SEARCH"
  AGENT_WRITER = "WRITER"
  AGENT_CRITIQUE = "CRITIQUE"
  AGENT_DESIGN = "DESIGN"

  # All valid agent names
  VALID_AGENT_NAMES = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN
  ].freeze

  # Agent execution order
  AGENT_ORDER = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN
  ].freeze

  # Agent output statuses
  STATUS_PENDING = "pending"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED = "failed"

  # All valid statuses
  VALID_STATUSES = [
    STATUS_PENDING,
    STATUS_COMPLETED,
    STATUS_FAILED
  ].freeze

  # Lead stages (for stage progression)
  STAGE_QUEUED = "queued"
  STAGE_SEARCHED = "searched"
  STAGE_WRITTEN = "written"
  STAGE_CRITIQUED = "critiqued"
  STAGE_DESIGNED = "designed"
  STAGE_COMPLETED = "completed"

  # Stage progression order
  STAGE_PROGRESSION = [
    STAGE_QUEUED,
    STAGE_SEARCHED,
    STAGE_WRITTEN,
    STAGE_CRITIQUED,
    STAGE_DESIGNED,
    STAGE_COMPLETED
  ].freeze

  AUTO_KNOWN_PROVIDERS = {
    "gmail.com"        => { address: "smtp.gmail.com",        port: 587 },
    "googlemail.com"   => { address: "smtp.gmail.com",        port: 587 },
    "outlook.com"      => { address: "smtp.office365.com",    port: 587 },
    "hotmail.com"      => { address: "smtp.office365.com",    port: 587 },
    "live.com"         => { address: "smtp.office365.com",    port: 587 },
    "yahoo.com"        => { address: "smtp.mail.yahoo.com",   port: 465 },
    "icloud.com"       => { address: "smtp.mail.me.com",      port: 587 },
    "me.com"           => { address: "smtp.mail.me.com",      port: 587 },
    "mac.com"          => { address: "smtp.mail.me.com",      port: 587 },
    "zoho.com"         => { address: "smtp.zoho.com",         port: 587 },
    "proton.me"        => { address: "smtp.protonmail.ch",    port: 465 },
    "protonmail.com"   => { address: "smtp.protonmail.ch",    port: 465 },
    "fastmail.com"     => { address: "smtp.fastmail.com",     port: 465 },
    "gmx.com"          => { address: "smtp.gmx.com",          port: 465 },
    "aol.com"          => { address: "smtp.aol.com",          port: 587 },
    "yandex.com"       => { address: "smtp.yandex.com",       port: 465 },
    "yandex.ru"        => { address: "smtp.yandex.ru",        port: 465 }
}

  MX_PATTERNS = {
    /google/       => :gmail,
    /outlook|office365|microsoft/ => :office365,
    /zoho/         => :zoho,
    /yahoodns|yahoo/ => :yahoo,
    /icloud|apple/ => :icloud,
    /proton/       => :protonmail,
    /fastmail/     => :fastmail,
    /gmx/          => :gmx,
    /aol/          => :aol,
    /yandex/       => :yandex
  }

  SMTP_PROVIDERS = {
    gmail:      { address: "smtp.gmail.com",        port: 587 },
    office365:  { address: "smtp.office365.com",    port: 587 },
    zoho:       { address: "smtp.zoho.com",         port: 587 },
    yahoo:      { address: "smtp.mail.yahoo.com",   port: 465 },
    icloud:     { address: "smtp.mail.me.com",      port: 587 },
    protonmail: { address: "smtp.protonmail.ch",    port: 465 },
    fastmail:   { address: "smtp.fastmail.com",     port: 465 },
    gmx:        { address: "smtp.gmx.com",          port: 465 },
    aol:        { address: "smtp.aol.com",          port: 587 },
    yandex:     { address: "smtp.yandex.ru",        port: 465 }
  }

  # Providers that effectively require 2FA + App Password for SMTP
  PROVIDER_2FA = {
    "gmail.com"       => { app_password_link: "https://myaccount.google.com/apppasswords" },
    "googlemail.com"  => { app_password_link: "https://myaccount.google.com/apppasswords" },
    "yahoo.com"       => { app_password_link: "https://login.yahoo.com/account/security" },
    "outlook.com"     => { app_password_link: "https://account.live.com/proofs/Manage" },
    "hotmail.com"     => { app_password_link: "https://account.live.com/proofs/Manage" },
    "live.com"        => { app_password_link: "https://account.live.com/proofs/Manage" },
    "icloud.com"      => { app_password_link: "https://appleid.apple.com/account/manage" }
    }.freeze

  APP_PASSWORD_PROVIDERS = {
    "gmail.com" => "https://myaccount.google.com/apppasswords",
    "googlemail.com" => "https://myaccount.google.com/apppasswords",
    "outlook.com" => "https://account.live.com/proofs/AppPassword",
    "hotmail.com" => "https://account.live.com/proofs/AppPassword",
    "live.com" => "https://account.live.com/proofs/AppPassword",
    "yahoo.com" => "https://login.yahoo.com/myaccount/security/app-password",
    "zoho.com" => "https://accounts.zoho.com/myaccount/security/apppassword"
  }

  DETAILED_2FA_INSTRUCTIONS = {
    "gmail.com" => {
      title: "How to Enable 2FA and Create an App Password (Gmail)",
      steps: [
        "Visit your Google Account Security page.",
        "Enable 2-Step Verification (if not already enabled).",
        "After enabling 2FA, return to the Security page.",
        "Click 'App Passwords' (only appears after enabling 2FA).",
        "Choose 'Mail' as the app, and 'Other' for device.",
        "Generate the password and paste it into the App Password field above."
      ],
      link: "https://myaccount.google.com/apppasswords"
    },

    "outlook.com" => {
      title: "How to Generate an Outlook/Hotmail App Password",
      steps: [
        "Go to your Microsoft Account Security page.",
        "Enable Two-Step Verification if not already enabled.",
        "After enabling 2FA, go back to the Security page.",
        "Select 'Create a new app password'.",
        "Use the generated password in the App Password field above."
      ],
      link: "https://account.live.com/proofs/manage"
    },

    "hotmail.com" => :outlook,
    "live.com"    => :outlook,

    "yahoo.com" => {
      title: "How to Generate a Yahoo Mail App Password",
      steps: [
        "Log into your Yahoo account.",
        "Open Account Security.",
        "Enable Two-step verification.",
        "Find the 'Generate App Password' section.",
        "Generate a password for Mail and paste it above."
      ],
      link: "https://login.yahoo.com/account/security"
    },

    "icloud.com" => {
      title: "How to Generate an iCloud Mail App Password",
      steps: [
        "Log into your Apple ID account.",
        "Go to 'Security' settings.",
        "Enable Two-factor authentication.",
        "Under 'App-Specific Passwords', click 'Generate Password'.",
        "Use this password in your App Password field above."
      ],
      link: "https://appleid.apple.com/account/manage"
    }
  }
end
