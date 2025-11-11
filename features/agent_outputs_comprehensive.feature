Feature: Agent Outputs Management
  As an authenticated user
  I want to view and manage agent outputs
  So that I can review and edit generated content

  Background:
    Given I am logged in

  Scenario: Get all agent outputs for a lead
    Given a lead exists for my campaign
    And the lead has a "SEARCH" agent output
    And the lead has a "WRITER" agent output
    And the lead has a "CRITIQUE" agent output
    When I send a GET request to "/api/v1/leads/#{@lead.id}/agent_outputs"
    Then the response status should be 200
    And the JSON response should include "outputs"
    And the outputs should include "SEARCH"
    And the outputs should include "WRITER"
    And the outputs should include "CRITIQUE"

  Scenario: Get agent outputs for lead with no outputs
    Given a lead exists for my campaign
    When I send a GET request to "/api/v1/leads/#{@lead.id}/agent_outputs"
    Then the response status should be 200
    And the JSON response should include "outputs"
    And the outputs array should be empty

  Scenario: Update DESIGN agent output
    Given a lead exists for my campaign
    And the lead has a "DESIGN" agent output
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "DESIGN", "content": "Updated formatted email content"}
      """
    Then the response status should be 200
    And the JSON response should include "outputData"

  Scenario: Cannot update agent output for another user's lead
    Given a lead exists for my campaign
    And there is another user with a separate campaign
    And the other user has a lead
    When I send a PATCH request to "/api/v1/leads/#{@other_lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "WRITER", "content": "Hacked content"}
      """
    Then the response status should be 404

  Scenario: Update agent output with invalid agent name
    Given a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "INVALID", "content": "Test"}
      """
    Then the response status should be 422

  Scenario: Get agent outputs includes output data
    Given a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    When I send a GET request to "/api/v1/leads/#{@lead.id}/agent_outputs"
    Then the response status should be 200
    And the WRITER output should include "email" in outputData

