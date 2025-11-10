Feature: Create a campaign via API
  As an authenticated user
  I want to create a campaign
  So that I can organize my outreach

  Scenario: Create campaign successfully
    Given I am logged in
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "Q4 Outreach", "sharedSettings": {"brand_voice": {"tone": "professional", "persona": "founder"}, "primary_goal": "book_call"}}}
      """
    Then the response status should be 201
    And the JSON response should include "title" with "Q4 Outreach"


