Feature: Create a lead via API
  As an authenticated user
  I want to add a lead to my campaign
  So that I can run agents on it

  Scenario: Create lead successfully
    Given a campaign titled "Prospecting" exists for me
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "Alice", "email": "alice@example.com", "title": "CTO", "company": "Acme", "website": "https://acme.test"}}
      """
    Then the response status should be 201
    And the JSON response should include "email" with "alice@example.com"


