Feature: Run agents error handling
  As an authenticated user
  I want clear errors when running agents on missing leads
  So that I understand what went wrong

  Scenario: Run agents on non-existent lead returns 404
    Given I am logged in
    When I send a POST request to "/api/v1/leads/999999/run_agents"
    Then the response status should be 404


