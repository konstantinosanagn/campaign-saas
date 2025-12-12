Feature: Tavily Search Agent API integration
  As a developer
  I want the search agent to handle Tavily API responses robustly
  So that errors and edge cases are logged and handled gracefully

  Scenario: Tavily API returns no results field
    Given the Tavily API responds without a "results" field
    When the search agent performs a search
    Then a warning should be logged about missing results
    And an empty array should be returned

  Scenario: Tavily API returns valid results
    Given the Tavily API responds with a valid "results" array
    When the search agent performs a search
    Then the results should be mapped and returned

  Scenario: Tavily API response parsing raises an exception
    Given the Tavily API responds with invalid data
    And parsing the response raises an exception
    When the search agent performs a search
    Then an error should be logged about the failure
    And an empty array should be returned
