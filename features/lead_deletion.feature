Feature: Lead Deletion
  As an authenticated user
  I want to delete leads from my campaigns
  So that I can remove unwanted prospects

  Background:
    Given I am logged in

  Scenario: Delete a lead successfully
    Given a lead exists for my campaign
    When I send a DELETE request to "/api/v1/leads/#{@lead.id}"
    Then the response status should be 204

  Scenario: Cannot delete another user's lead
    Given a lead exists for my campaign
    And there is another user with a separate campaign
    And the other user has a lead
    When I send a DELETE request to "/api/v1/leads/#{@other_lead.id}"
    Then the response status should be 404

  Scenario: Deleting lead removes associated agent outputs
    Given a lead exists for my campaign
    And the lead has a "SEARCH" agent output
    And the lead has a "WRITER" agent output
    When I send a DELETE request to "/api/v1/leads/#{@lead.id}"
    Then the response status should be 204
    And the agent outputs should be deleted

  Scenario: Delete non-existent lead returns 404
    Given I am logged in
    When I send a DELETE request to "/api/v1/leads/999999"
    Then the response status should be 404

