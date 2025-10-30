Feature: Campaign authorization boundaries
  As a campaign owner
  I want to be prevented from touching others' campaigns
  So that data stays private

  Background:
    Given a user exists

  Scenario: I cannot update a campaign that isn't mine
    Given a campaign titled "Someone else's" exists for me
    # Simulate another user's campaign by reassigning to a different user
    And there is another user with a separate campaign
    When I send a PATCH request to "/api/v1/campaigns/#{@other_campaign.id}" with JSON:
      """
      {"campaign": {"title": "Hacked"}}
      """
    Then the response status should be 422


