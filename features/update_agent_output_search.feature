Feature: Update SEARCH agent output via API
  As an authenticated user
  I want to correct search data
  So that downstream agents use accurate info

  Scenario: Update SEARCH output data
    Given a lead exists for my campaign
    And a "SEARCH" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "SEARCH", "updatedData": {"urls": ["https://example.com"]}}
      """
    Then the response status should be 200
    And the JSON response should include "outputData"


