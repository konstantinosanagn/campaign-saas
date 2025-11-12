Feature: JsonbValidator Error Paths
  As an authenticated user
  I want validation errors when I submit invalid JSONB data
  So that data integrity is maintained

  Background:
    Given I am logged in

  Scenario: AgentConfig rejects invalid JSONB data type (string instead of integer)
    Given a campaign titled "Test Campaign" exists for me
    # JsonbValidator checks if string can be converted to integer (line 80)
    # "not_a_number" cannot be converted, so it should fail
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agentConfig": {"agentName": "WRITER", "enabled": true, "settings": {"num_variants_per_lead": "not_a_number"}}}
      """
    Then the response status should be 422
    And the JSON response should include "errors"

  Scenario: AgentConfig rejects invalid JSONB structure (non-empty array instead of object)
    Given a campaign titled "Test Campaign" exists for me
    # Delete existing WRITER config if it exists to avoid conflicts
    And any existing "WRITER" agent config is deleted
    # JsonbValidator expects settings to be an object (Hash), not an array
    # Line 38 allows empty array if allow_empty is true, but non-empty array should fail
    # Line 47-49 checks: unless value.is_a?(Hash) -> adds error
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agentConfig": {"agentName": "WRITER", "enabled": true, "settings": ["invalid"]}}
      """
    Then the response status should be 422
    And the JSON response should include "errors"

  Scenario: AgentConfig accepts empty settings (allow_empty: true by default)
    Given a campaign titled "Test Campaign" exists for me
    # Empty settings should be allowed (allow_empty: true by default)
    # Use CRITIQUE agent to avoid conflicts with existing configs
    And any existing "CRITIQUE" agent config is deleted
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
        {"agent_config": {"agent_name": "CRITIQUE", "enabled": true, "settings": {}}}
      """
    Then the response status should be 201
    # Empty settings should be allowed

  Scenario: AgentOutput rejects invalid JSONB data type
    Given a lead exists for my campaign
    # Create agent output with invalid data type in output_data
    When I try to create an agent output with invalid JSONB data
    Then the agent output should have validation errors

  Scenario: AgentConfig accepts valid nested object structure
    Given a campaign titled "Test Campaign" exists for me
    # Delete existing WRITER config if it exists to avoid conflicts
    And any existing "WRITER" agent config is deleted
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agent_name": "WRITER", "enabled": true, "settings": {"tone": "professional", "email_length": "short"}}}
      """
    Then the response status should be 201
    And the JSON response should include "settings"
    # Note: JsonbValidator validates types but allows flexible schemas

  Scenario: AgentConfig accepts valid array type in settings
    Given a campaign titled "Test Campaign" exists for me
    # Delete existing SEARCH config if it exists to avoid conflicts
    And any existing "SEARCH" agent config is deleted
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
        {"agent_config": {"agent_name": "SEARCH", "enabled": true, "settings": {"extracted_fields": ["urls", "titles"]}}}
      """
    Then the response status should be 201
    And the JSON response should include "settings"
    # Note: JsonbValidator validates array types when specified in schema

