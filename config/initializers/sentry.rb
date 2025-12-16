Sentry.init do |config|
  # Configure your DSN via:
  #   SENTRY_DSN=...
  config.dsn = ENV["SENTRY_DSN"]

  # Do not send user-identifying information by default.
  config.send_default_pii = false

  config.before_send = lambda do |event, hint|
    begin
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      event.extra = filter.filter(event.extra) if event.respond_to?(:extra) && event.extra
      event.tags  = filter.filter(event.tags)  if event.respond_to?(:tags)  && event.tags

      if event.respond_to?(:request) && event.request
        req = event.request

        if req.is_a?(Hash)
          event.request = filter.filter(req)
        else
          # sentry-ruby request interface (best-effort)
          if req.respond_to?(:data) && req.data
            req.data = filter.filter(req.data)
          end
          if req.respond_to?(:headers) && req.headers
            req.headers = filter.filter(req.headers)
          end
          if req.respond_to?(:env) && req.env
            req.env = filter.filter(req.env)
          end
        end
      end

      if event.respond_to?(:breadcrumbs) && event.breadcrumbs
        event.breadcrumbs.values.each do |crumb|
          next unless crumb.respond_to?(:data) && crumb.data
          crumb.data = filter.filter(crumb.data)
        end
      end
    rescue => e
      Rails.logger.error("[Sentry before_send] #{e.class}: #{e.message}")
    end

    event
  end
end
