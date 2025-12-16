class HealthController < ActionController::API
  # Public minimal health endpoint.
  #
  # Intentionally does NOT include version/adapter details.
  def health
    render json: { ok: true }
  end

  # Restricted detailed health endpoint.
  #
  # Protected via basic auth using HEALTHZ_USER / HEALTHZ_PASS.
  def healthz
    require_healthz_basic_auth!

    checks = {}

    # DB check (cheap)
    checks[:db] = ActiveRecord::Base.connection.active? rescue false

    # Redis check (optional)
    checks[:redis] =
      begin
        redis_url = ENV["REDIS_TLS_URL"].presence || ENV["REDIS_URL"].presence
        redis_url.present?
      rescue
        false
      end

    ok = checks.values.all?

    render json: {
      ok: ok,
      checks: checks,
      env: Rails.env,
      revision: ENV["HEROKU_SLUG_COMMIT"].presence
    }.compact, status: (ok ? :ok : :service_unavailable)
  end

  private

  def require_healthz_basic_auth!
    user = ENV["HEALTHZ_USER"].to_s
    pass = ENV["HEALTHZ_PASS"].to_s

    head :forbidden and return if user.empty? || pass.empty?

    authenticate_or_request_with_http_basic do |u, p|
      ActiveSupport::SecurityUtils.secure_compare(u.to_s, user) &&
        ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass)
    end
  end
end
