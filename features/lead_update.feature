Feature: Update a lead via API
  As an authenticated user
  I want to update a lead in my campaign
  So that I can correct or enrich data

  Scenario: Update lead title
    Given a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}" with JSON:
      """
      {"lead": {"title": "VP Engineering"}}
      """
    Then the response status should be 200
    And the JSON response should include "title" with "VP Engineering"


