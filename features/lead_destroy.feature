Feature: Delete a lead via API
  As an authenticated user
  I want to delete a lead in my campaign
  So that I can remove irrelevant prospects

  Scenario: Delete lead successfully
    Given a lead exists for my campaign
    When I send a DELETE request to "/api/v1/leads/#{@lead.id}"
    Then the response status should be 204


