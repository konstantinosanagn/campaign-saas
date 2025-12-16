# Rate limiting configuration using rack-attack
# See: https://github.com/rack/rack-attack

require "digest"

class Rack::Attack
  # Optional gate (useful for local dev / review apps)
  Rack::Attack.enabled = ENV.fetch("RACK_ATTACK_ENABLED", "true") == "true"

  # Cache store (critical: must be shared in multi-dyno environments)
  redis_url = ENV["REDIS_TLS_URL"].presence || ENV["REDIS_URL"].presence

  if Rack::Attack.enabled
    if Rails.env.production?
      raise "Missing REDIS_URL/REDIS_TLS_URL for Rack::Attack" unless redis_url.present?

      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
        url: redis_url,
        pool_size: Integer(ENV.fetch("RAILS_MAX_THREADS", 5)),
        pool_timeout: 5
      )
    else
      # Development/test: in-memory store is acceptable.
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    end
  end

  USER_DISCRIMINATOR = lambda do |req|
    # Prefer Warden user id when available
    warden_user_id = req.env["warden"]&.user&.id rescue nil
    return warden_user_id.to_s if warden_user_id.present?

    # Devise cookie session (if applicable)
    session_user_id = req.session["warden.user.user.key"]&.dig(0, 0) rescue nil
    return session_user_id.to_s if session_user_id.present?

    # Token/JWT Authorization header fingerprint
    auth_header = req.get_header("HTTP_AUTHORIZATION")
    if auth_header.present?
      return "token_#{Digest::SHA256.hexdigest(auth_header)}"
    end

    # Fallback discriminator
    req.ip.to_s
  end

  # Rate limit exclusions
  safelist("health_and_assets") do |req|
    req.path == "/health" || req.path == "/healthz" || req.path == "/up" ||
      req.path.start_with?("/assets") || req.path.start_with?("/packs") || req.path.start_with?("/rails/active_storage")
  end

  # Throttles: agent/run endpoints (must require auth; discriminator relies on that)
  throttle("api/leads/run_agents", limit: 10, period: 1.minute) do |req|
    next unless req.post? && req.path.match?(%r{\A/api/v1/leads/\d+/run_agents\z})
    USER_DISCRIMINATOR.call(req)
  end

  throttle("api/leads/batch_run_agents", limit: 3, period: 1.minute) do |req|
    next unless req.post? && req.path == "/api/v1/leads/batch_run_agents"
    USER_DISCRIMINATOR.call(req)
  end

  throttle("api/leads/resume_run", limit: 5, period: 1.minute) do |req|
    next unless req.post? && req.path.match?(%r{\A/api/v1/leads/\d+/resume_run\z})
    USER_DISCRIMINATOR.call(req)
  end

  # Admin/debug endpoints (sensitive; keep low volume)
  throttle("admin/api", limit: 30, period: 1.minute) do |req|
    next unless req.path.start_with?("/admin/")
    "admin_#{USER_DISCRIMINATOR.call(req)}"
  end

  # Throttle login attempts (nice-to-have baseline security)
  throttle("logins/ip", limit: 5, period: 20.minutes) do |req|
    req.ip if (req.path == "/users/sign_in" || req.path == "/login") && req.post?
  end

  # Throttle password reset requests
  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # 429 responses: consistent JSON + Retry-After header
  Rack::Attack.throttled_response_retry_after_header = true
  Rack::Attack.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period]

    body = { error: "rate_limited", retry_after: retry_after }.to_json
    headers = { "Content-Type" => "application/json" }
    headers["Retry-After"] = retry_after.to_s if retry_after

    [429, headers, [body]]
  end
end
