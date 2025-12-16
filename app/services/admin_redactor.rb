class AdminRedactor
  # Centralized redaction for admin/debug tooling responses.
  #
  # Contract:
  # - Use the same filter list as logs / Sentry (ActiveSupport::ParameterFilter)
  # - Additionally support "hard redaction" for known-dangerous blobs by caller
  def self.redact_hash(hash)
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filter.filter(deep_dup(hash || {}))
  end

  def self.deep_dup(value)
    case value
    when Hash
      value.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
    when Array
      value.map { |v| deep_dup(v) }
    else
      value
    end
  end
end
