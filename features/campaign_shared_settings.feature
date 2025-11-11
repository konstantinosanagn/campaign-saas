Feature: Campaign Shared Settings
  As an authenticated user
  I want to configure shared settings for my campaigns
  So that agents use consistent branding and goals

  Background:
    Given I am logged in

  Scenario: Create campaign with shared settings
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "Branded Campaign", "sharedSettings": {"brand_voice": {"tone": "casual", "persona": "founder"}, "primary_goal": "demo_request"}}}
      """
    Then the response status should be 201
    And the JSON response should include "sharedSettings"

  Scenario: Update campaign shared settings
    Given a campaign titled "Settings Test" exists for me
    When I send a PATCH request to "/api/v1/campaigns/#{@campaign.id}" with JSON:
      """
      {"campaign": {"sharedSettings": {"brand_voice": {"tone": "formal", "persona": "executive"}, "primary_goal": "book_call"}}}
      """
    Then the response status should be 200
    And the JSON nested value at "sharedSettings.brand_voice.tone" should equal "formal"

  Scenario: Campaign shared settings are used by agents
    Given a campaign titled "Settings Test" exists for me
    And the campaign has shared settings with tone "professional"
    And a lead exists for my campaign
    When I run agents on the lead
    Then the agents should use the campaign's shared settings

