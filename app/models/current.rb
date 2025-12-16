# Request-scoped storage for per-request caching and attributes
# Automatically cleared at the end of each request (web requests)
# Also cleared at the start/end of each background job (see ApplicationJob)
class Current < ActiveSupport::CurrentAttributes
  attribute :config_cache

  # Lazy initialization: returns empty hash if not set, so callers never need nil checks
  def config_cache
    value = super
    return value if value

    self.config_cache = {}
  end
end
