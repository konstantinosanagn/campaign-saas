Feature: Lead Validation
  As an authenticated user
  I want validation errors for invalid lead data
  So that I can correct mistakes

  Background:
    Given I am logged in
    And a campaign titled "Validation Test" exists for me

  Scenario: Missing email yields validation error
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "No Email", "title": "CTO", "company": "Acme"}}
      """
    Then the response status should be 422
    And the JSON response should include "errors"

  Scenario: Missing name yields validation error
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "email": "test@example.com", "title": "CTO", "company": "Acme"}}
      """
    Then the response status should be 422

  Scenario: Missing title yields validation error
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "Test", "email": "test@example.com", "company": "Acme"}}
      """
    Then the response status should be 422

  Scenario: Missing company yields validation error
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "Test", "email": "test@example.com", "title": "CTO"}}
      """
    Then the response status should be 422

  Scenario: Invalid email format yields validation error
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "Test", "email": "invalid-email", "title": "CTO", "company": "Acme"}}
      """
    Then the response status should be 422

  Scenario: Cannot create lead for non-existent campaign
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": 999999, "name": "Test", "email": "test@example.com", "title": "CTO", "company": "Acme"}}
      """
    Then the response status should be 422

  Scenario: Cannot create lead for another user's campaign
    Given there is another user with a separate campaign
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@other_campaign.id}, "name": "Test", "email": "test@example.com", "title": "CTO", "company": "Acme"}}
      """
    Then the response status should be 422

