Feature: Manage API keys via session
  As an authenticated user
  I want to save and retrieve my API keys
  So that agents can use them

  Scenario: Update and read API keys
    Given I am logged in
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": "LLM-123", "tavilyApiKey": "TAV-456"}
      """
    Then the response status should be 200
    And the JSON response should include "llmApiKey" with "LLM-123"
    And the JSON response should include "tavilyApiKey" with "TAV-456"
    When I send a GET request to "/api/v1/api_keys"
    Then the response status should be 200
    And the JSON response should include "llmApiKey" with "LLM-123"
    And the JSON response should include "tavilyApiKey" with "TAV-456"


