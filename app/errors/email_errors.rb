##
# EmailErrors
#
# Domain-specific exceptions for email sending operations.
# These help distinguish between temporary (retryable) and permanent (non-retryable) failures.
#
module EmailErrors
  class EmailError < StandardError
    attr_reader :provider, :lead_id, :temporary

    def initialize(message = nil, provider: nil, lead_id: nil, temporary: false)
      super(message)
      @provider  = provider
      @lead_id   = lead_id
      @temporary = temporary
    end
  end

  class TemporaryEmailError < EmailError
    def initialize(message = nil, provider: nil, lead_id: nil)
      super(message, provider: provider, lead_id: lead_id, temporary: true)
    end
  end

  class PermanentEmailError < EmailError
    def initialize(message = nil, provider: nil, lead_id: nil)
      super(message, provider: provider, lead_id: lead_id, temporary: false)
    end
  end

  # Used when wrapping low-level provider issues before classification
  class EmailProviderError < StandardError; end
end

# Create top-level aliases for backward compatibility
EmailError = EmailErrors::EmailError
TemporaryEmailError = EmailErrors::TemporaryEmailError
PermanentEmailError = EmailErrors::PermanentEmailError
EmailProviderError = EmailErrors::EmailProviderError
