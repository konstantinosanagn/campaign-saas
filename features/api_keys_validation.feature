Feature: API Keys Validation
  As an authenticated user
  I want to validate my API keys
  So that agents can execute successfully

  Background:
    Given I am logged in

  Scenario: Update API keys successfully
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": "valid-llm-key", "tavilyApiKey": "valid-tavily-key"}
      """
    Then the response status should be 200
    And the JSON response should include "llmApiKey" with "valid-llm-key"
    And the JSON response should include "tavilyApiKey" with "valid-tavily-key"

  Scenario: Get API keys returns stored keys
    Given I have API keys configured
    When I send a GET request to "/api/v1/api_keys"
    Then the response status should be 200
    And the JSON response should include "llmApiKey"
    And the JSON response should include "tavilyApiKey"

  Scenario: Update only LLM API key
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": "new-llm-key"}
      """
    Then the response status should be 200
    And the JSON response should include "llmApiKey" with "new-llm-key"

  Scenario: Update only Tavily API key
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"tavilyApiKey": "new-tavily-key"}
      """
    Then the response status should be 200
    And the JSON response should include "tavilyApiKey" with "new-tavily-key"

  Scenario: Clear API keys
    Given I have API keys configured
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": "", "tavilyApiKey": ""}
      """
    Then the response status should be 200
    And the JSON response should include "llmApiKey" with ""
    And the JSON response should include "tavilyApiKey" with ""

