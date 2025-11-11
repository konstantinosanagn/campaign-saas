Feature: Campaign Validation
  As an authenticated user
  I want validation errors for invalid campaign data
  So that I can correct mistakes

  Background:
    Given I am logged in

  Scenario: Missing title yields validation error
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "", "sharedSettings": {}}}
      """
    Then the response status should be 422
    And the JSON response should include "errors"

  Scenario: Nil title yields validation error
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"sharedSettings": {}}}
      """
    Then the response status should be 422

  Scenario: Very long title is accepted
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "A" * 255, "sharedSettings": {}}}
      """
    Then the response status should be 201

  Scenario: Campaign can be created with empty shared settings
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "Minimal Campaign", "sharedSettings": {}}}
      """
    Then the response status should be 201

  Scenario: Campaign can be created with complex shared settings
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "Complex Campaign", "sharedSettings": {"brand_voice": {"tone": "professional", "persona": "founder"}, "primary_goal": "book_call", "custom_field": "value"}}}
      """
    Then the response status should be 201

