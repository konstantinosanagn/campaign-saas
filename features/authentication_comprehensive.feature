Feature: Authentication and Authorization
  As a user
  I want secure access to my data
  So that my campaigns and leads are protected

  Background:
    Given authentication is enabled

  Scenario: Unauthenticated user cannot access campaigns
    Given I am not logged in
    When I send a GET request to "/api/v1/campaigns"
    Then the response status should be 401

  Scenario: Unauthenticated user cannot create campaigns
    Given I am not logged in
    When I send a POST request to "/api/v1/campaigns" with JSON:
      """
      {"campaign": {"title": "Unauthorized Campaign"}}
      """
    Then the response status should be 401

  Scenario: User can only see their own campaigns
    Given I am logged in
    And a campaign titled "My Campaign" exists for me
    And there is another user with a separate campaign
    When I send a GET request to "/api/v1/campaigns"
    Then the response status should be 200
    And the campaigns should only include my campaigns

  Scenario: User cannot update another user's campaign
    Given I am logged in
    And there is another user with a separate campaign
    When I send a PATCH request to "/api/v1/campaigns/#{@other_campaign.id}" with JSON:
      """
      {"campaign": {"title": "Hacked"}}
      """
    Then the response status should be 422

  Scenario: User cannot delete another user's campaign
    Given I am logged in
    And there is another user with a separate campaign
    When I send a DELETE request to "/api/v1/campaigns/#{@other_campaign.id}"
    Then the response status should be 404

  Scenario: User cannot access another user's leads
    Given I am logged in
    And there is another user with a separate campaign
    And the other user has a lead
    When I send a GET request to "/api/v1/leads/#{@other_lead.id}/agent_outputs"
    Then the response status should be 404

  Scenario: User cannot run agents on another user's lead
    Given I am logged in
    And there is another user with a separate campaign
    And the other user has a lead
    When I send a POST request to "/api/v1/leads/#{@other_lead.id}/run_agents"
    Then the response status should be 404

