##
# Google::Apis Stub
#
# Provides stub classes for Google::Apis errors if the google-apis-client gem
# is not available in the test environment. Only loaded if needed.
#
unless defined?(Google::Apis::RateLimitError)
  module Google
    module Apis
      class RateLimitError < StandardError; end
      class ServerError < StandardError; end
      class AuthorizationError < StandardError; end
    end
  end
end
