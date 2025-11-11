Feature: Agent Execution Workflow
  As an authenticated user
  I want to run agents on leads
  So that I can generate personalized emails

  Background:
    Given I am logged in
    And I have API keys configured

  Scenario: Run agents on a lead with all agents enabled
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the JSON response should include "status"
    And the JSON response should include "outputs"

  Scenario: Run agents progresses through DESIGN stage
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "CRITIQUE" agent output with email content
    And the campaign has a "DESIGN" agent config
    And the DESIGN agent will return formatted email
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the lead stage should be "designed"
    And the outputs should include "DESIGN"

  Scenario: Run agents with DESIGN agent disabled skips to designed
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the campaign has a "DESIGN" agent config that is disabled
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the lead stage should be "designed"

  Scenario: DESIGN agent formats email with markdown
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "CRITIQUE" agent output with email content
    And the campaign has a "DESIGN" agent config
    And the DESIGN agent will return formatted email
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the DESIGN output should include formatted email

  Scenario: Run agents progresses lead through stages
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the lead stage should be "searched"

  Scenario: Run agents fails when API keys are missing
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And I do not have API keys configured
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 422
    And the JSON response should include "error"

  Scenario: Run agents on lead that already completed
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "completed"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the JSON response should include "status" with "completed"

  Scenario: Run agents with disabled agent skips that agent
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the campaign has a "SEARCH" agent config that is disabled
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the lead stage should advance past "searched"

  Scenario: Run agents stores outputs for each agent
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the lead should have agent outputs stored

  Scenario: Run agents handles agent execution errors gracefully
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the API service is unavailable
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents"
    Then the response status should be 200
    And the JSON response should include "failedAgents"

  Scenario: Run agents with async=true enqueues job
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    Then the response status should be 202
    And the JSON response should include "status" with "queued"
    And the JSON response should include "job_id"
    And an AgentExecutionJob should be enqueued

  Scenario: Run agents with async=false runs synchronously
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    And the Orchestrator is configured
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=false"
    Then the response status should be 200
    And the JSON response should include "status"
    And no jobs should be enqueued
    And the lead should have agent outputs stored

  Scenario: Run agents async handles job enqueue failure
    Given a campaign titled "Agent Test" exists for me
    And a lead exists for my campaign
    And job enqueueing will fail
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    Then the response status should be 500
    And the JSON response should include "error"

