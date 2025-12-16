Rails.application.config.after_initialize do
  # Guard against duplicate subscriptions in development reload flows.
  cfg = Rails.application.config.x
  cfg.lead_runs_notif_subscribed ||= false
  next if cfg.lead_runs_notif_subscribed

  cfg.lead_runs_notif_subscribed = true

  ActiveSupport::Notifications.subscribe("lead_runs.step_executed") do |name, start, finish, id, payload|
    duration_ms = ((finish - start) * 1000.0).round(1)
    StructuredLogger.log_event(name, payload.merge(duration_ms: duration_ms))
  rescue => e
    Rails.logger.error("[lead_runs.step_executed subscriber] #{e.class}: #{e.message}")
  end
end
