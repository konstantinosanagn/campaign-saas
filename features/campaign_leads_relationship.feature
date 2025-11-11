Feature: Campaign-Leads Relationship
  As an authenticated user
  I want to manage the relationship between campaigns and leads
  So that I can organize my outreach

  Background:
    Given I am logged in

  Scenario: List leads for a specific campaign
    Given a campaign titled "Campaign A" exists for me
    And the campaign has a lead with email "lead1@example.com"
    And the campaign has a lead with email "lead2@example.com"
    When I send a GET request to "/api/v1/leads"
    Then the response status should be 200
    And the JSON array response should have at least 2 items

  Scenario: Leads are scoped to user's campaigns
    Given a campaign titled "My Campaign" exists for me
    And the campaign has a lead with email "mylead@example.com"
    And there is another user with a separate campaign
    And the other user's campaign has a lead
    When I send a GET request to "/api/v1/leads"
    Then the response status should be 200
    And the leads should only include leads from my campaigns

  Scenario: Deleting campaign deletes associated leads
    Given a campaign titled "To Delete" exists for me
    And the campaign has a lead with email "lead@example.com"
    When I send a DELETE request to "/api/v1/campaigns/#{@campaign.id}"
    Then the response status should be 204
    And the lead should be deleted

  Scenario: Updating lead does not change campaign association
    Given a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}" with JSON:
      """
      {"lead": {"name": "Updated Name"}}
      """
    Then the response status should be 200
    And the lead should still belong to the same campaign

