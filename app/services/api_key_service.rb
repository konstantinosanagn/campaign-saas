##
# ApiKeyService
#
# Handles retrieval of API keys from the session for agent services.
# Provides centralized access to Gemini and Tavily API keys with proper error handling.
#
# Usage:
#   gemini_key = ApiKeyService.get_gemini_api_key(session)
#   tavily_key = ApiKeyService.get_tavily_api_key(session)
#
class ApiKeyService
  # Use symbol keys to match session storage format (matches api_keys_controller)
  LLM_KEY_NAME = :llm_api_key
  TAVILY_KEY_NAME = :tavily_api_key

  class << self
    ##
    # Retrieves the Gemini API key from the session
    # @param session [Hash] Rails session object
    # @return [String] Gemini API key
    # @raise [ArgumentError] if API key is missing or blank
    def get_gemini_api_key(session)
      key = session[LLM_KEY_NAME]
      
      if key.blank?
        raise ArgumentError, "Gemini API key is required. Please add your Gemini API key in the API Keys section."
      end
      
      key
    end

    ##
    # Retrieves the Tavily API key from the session
    # @param session [Hash] Rails session object
    # @return [String] Tavily API key
    # @raise [ArgumentError] if API key is missing or blank
    def get_tavily_api_key(session)
      key = session[TAVILY_KEY_NAME]
      
      if key.blank?
        raise ArgumentError, "Tavily API key is required. Please add your Tavily API key in the API Keys section."
      end
      
      key
    end

    ##
    # Checks if both API keys are available in the session
    # @param session [Hash] Rails session object
    # @return [Boolean] true if both keys are present and not blank
    def keys_available?(session)
      session[LLM_KEY_NAME].present? && session[TAVILY_KEY_NAME].present?
    end

    ##
    # Returns a list of missing API keys
    # @param session [Hash] Rails session object
    # @return [Array<String>] Array of missing key names
    def missing_keys(session)
      missing = []
      missing << 'Gemini' if session[LLM_KEY_NAME].blank?
      missing << 'Tavily' if session[TAVILY_KEY_NAME].blank?
      missing
    end
  end
end
