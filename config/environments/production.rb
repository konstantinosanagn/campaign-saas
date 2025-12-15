require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.headers = {
    "cache-control" => "public, max-age=#{1.year.to_i}"
  }

  # Serve static files from the `/public` folder (required for Heroku)
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Do not fallback to assets pipeline if a precompiled asset is missed
  # Assets are precompiled during build, so no need to compile on-the-fly
  config.assets.compile = false

  if defined?(ActiveStorage::Engine)
    config.active_storage.service = :local
  end

  # Allow disabling SSL for local production testing
  # Set DISABLE_SSL=true environment variable to disable SSL enforcement
  unless ENV["DISABLE_SSL"] == "true"
    config.assume_ssl = true
    config.force_ssl = true
  end

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", "example.com"),
    protocol: "https"
  }

  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
    port: ENV.fetch("SMTP_PORT", "587").to_i,
    domain: ENV.fetch("SMTP_DOMAIN", "gmail.com"),
    user_name: ENV["SMTP_USER_NAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: (ENV["SMTP_AUTHENTICATION"] || "plain").to_sym,
    enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
  }

  config.i18n.fallbacks = true

  if defined?(ActiveRecord)
    config.active_record.dump_schema_after_migration = false
    config.active_record.attributes_for_inspect = [ :id ]

    # Temporary migration safety valve:
    # Allow reading existing plaintext rows during the encryption rollout window.
    # After backfill completes, flip ALLOW_UNENCRYPTED_USER_SECRETS=false (no code deploy).
    config.active_record.encryption.support_unencrypted_data =
      ENV.fetch("ALLOW_UNENCRYPTED_USER_SECRETS", "false") == "true"
  end
end
