Feature: Agent Configuration Management
  As an authenticated user
  I want to manage agent configurations for my campaigns
  So that I can customize agent behavior

  Background:
    Given I am logged in

  Scenario: List agent configs for a campaign
    Given a campaign titled "Config Test" exists for me
    When I send a GET request to "/api/v1/campaigns/#{@campaign.id}/agent_configs"
    Then the response status should be 200
    And the JSON response should include "configs"

  Scenario: Get a specific agent config
    Given a campaign titled "Config Test" exists for me
    And the campaign has a "SEARCH" agent config
    When I send a GET request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}"
    Then the response status should be 200
    And the JSON response should include "agentName" with "SEARCH"

  Scenario: Create a new agent config
    Given a campaign titled "Config Test" exists for me
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agent_name": "SEARCH", "enabled": true, "settings": {"search_depth": "advanced"}}}
      """
    Then the response status should be 201
    And the JSON response should include "agentName" with "SEARCH"

  Scenario: Update agent config settings
    Given a campaign titled "Config Test" exists for me
    And the campaign has a "WRITER" agent config
    When I send a PATCH request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}" with JSON:
      """
      {"agent_config": {"enabled": false, "settings": {"email_length": "long"}}}
      """
    Then the response status should be 200
    And the JSON response should include "enabled" with false

  Scenario: Delete an agent config
    Given a campaign titled "Config Test" exists for me
    And the campaign has a "CRITIQUE" agent config
    When I send a DELETE request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}"
    Then the response status should be 204

  Scenario: Cannot create duplicate agent config
    Given a campaign titled "Config Test" exists for me
    And the campaign has a "SEARCH" agent config
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agent_name": "SEARCH", "enabled": true}}
      """
    Then the response status should be 422

  Scenario: Cannot create config with invalid agent name
    Given a campaign titled "Config Test" exists for me
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agent_name": "INVALID", "enabled": true}}
      """
    Then the response status should be 422

  Scenario: Cannot access agent configs for another user's campaign
    Given a campaign titled "My Campaign" exists for me
    And there is another user with a separate campaign
    When I send a GET request to "/api/v1/campaigns/#{@other_campaign.id}/agent_configs"
    Then the response status should be 404

