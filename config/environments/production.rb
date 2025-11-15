require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.headers = {
    "cache-control" => "public, max-age=#{1.year.to_i}"
  }

  if defined?(ActiveStorage::Engine)
    config.active_storage.service = :local
  end

  config.assume_ssl = true
  config.force_ssl = true

  config.log_tags = [:request_id]
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
    config.active_record.attributes_for_inspect = [:id]
  end
end
