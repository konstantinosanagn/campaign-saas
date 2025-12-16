module Agents
  class ApiError < StandardError
    attr_reader :error_code, :error_type, :provider_error

    def initialize(message, retryable:, error_code: nil, error_type: "unknown", provider_error: nil)
      super(message)
      @retryable = retryable
      @error_code = error_code
      @error_type = error_type
      @provider_error = provider_error
    end

    def retryable?
      @retryable
    end
  end
end
