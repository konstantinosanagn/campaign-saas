Feature: Update a campaign via API
  As an authenticated user
  I want to update my campaign
  So that I can change its title

  Scenario: Update campaign title
    Given a campaign titled "Initial" exists for me
    When I send a PATCH request to "/api/v1/campaigns/#{@campaign.id}" with JSON:
      """
      {"campaign": {"title": "Renamed"}}
      """
    Then the response status should be 200
    And the JSON response should include "title" with "Renamed"


