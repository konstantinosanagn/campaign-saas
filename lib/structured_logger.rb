module StructuredLogger
  def self.log_event(event_name, payload = {})
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(payload || {})

    Rails.logger.info(filtered.merge(event: event_name).to_json)
  end
end
