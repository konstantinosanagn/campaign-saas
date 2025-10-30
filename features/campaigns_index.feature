Feature: List my campaigns via API
  As an authenticated user
  I want to list my campaigns
  So that I can view what I’ve created

  Scenario: Get campaigns list
    Given a campaign titled "Listing Test" exists for me
    When I send a GET request to "/api/v1/campaigns"
    Then the response status should be 200
    And the JSON array response should have at least 1 item


