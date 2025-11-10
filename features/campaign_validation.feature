Feature: Campaign input validation
  As a campaign creator
  I want helpful errors when I submit invalid data
  So that I can fix mistakes quickly

  Scenario: Missing title yields validation error
    Given I am logged in
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "", "sharedSettings": {"brand_voice": {"tone": "professional", "persona": "founder"}, "primary_goal": "book_call"}}}
      """
    Then the response status should be 422


