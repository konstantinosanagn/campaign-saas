Feature: Retrieve agent outputs for a lead
  As an authenticated user
  I want to view agent outputs for a lead
  So that I can review generated content

  Scenario: Get agent outputs list
    Given a lead exists for my campaign
    And a "WRITER" agent output exists for the lead
    When I send a GET request to "/api/v1/leads/#{@lead.id}/agent_outputs"
    Then the response status should be 200
    And the JSON response should include "outputs"


