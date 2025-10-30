Feature: List my leads via API
  As an authenticated user
  I want to list my leads across campaigns
  So that I can review prospects

  Scenario: Get leads list
    Given a lead exists for my campaign
    When I send a GET request to "/api/v1/leads"
    Then the response status should be 200
    And the JSON array response should have at least 1 item


