##
# ApiKeyService
#
# Handles retrieval of API keys from the current user for agent services.
# Provides centralized access to Gemini and Tavily API keys with proper error handling.
#
# Usage:
#   gemini_key = ApiKeyService.get_gemini_api_key(user)
#   tavily_key = ApiKeyService.get_tavily_api_key(user)
#
class ApiKeyService
  class << self
    ##
    # Retrieves the Gemini API key from the user record
    # @param user [User] Current user
    # @return [String] Gemini API key
    # @raise [ArgumentError] if API key is missing or blank
    def get_gemini_api_key(user)
      key = user&.llm_api_key

      if key.blank?
        raise ArgumentError, "Gemini API key is required. Please add your Gemini API key in the API Keys section."
      end

      key
    end

    ##
    # Retrieves the Tavily API key from the user record
    # @param user [User] Current user
    # @return [String] Tavily API key
    # @raise [ArgumentError] if API key is missing or blank
    def get_tavily_api_key(user)
      key = user&.tavily_api_key

      if key.blank?
        raise ArgumentError, "Tavily API key is required. Please add your Tavily API key in the API Keys section."
      end

      key
    end

    ##
    # Checks if both API keys are available on the user record
    # @param user [User] Current user
    # @return [Boolean] true if both keys are present and not blank
    def keys_available?(user)
      user&.llm_api_key.present? && user&.tavily_api_key.present?
    end

    ##
    # Returns a list of missing API keys
    # @param user [User] Current user
    # @return [Array<String>] Array of missing key names
    def missing_keys(user)
      missing = []
      missing << "Gemini" if user&.llm_api_key.blank?
      missing << "Tavily" if user&.tavily_api_key.blank?
      missing
    end
  end
end
