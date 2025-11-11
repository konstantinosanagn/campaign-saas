Feature: Async Agent Execution
  As an authenticated user
  I want to run agents asynchronously via background jobs
  So that long-running agent operations don't block HTTP requests

  Background:
    Given I am logged in

  Scenario: Enqueue agent execution job with async parameter
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    Then the response status should be 202
    And the JSON response should include "status" with "queued"
    And the JSON response should include "job_id"
    And an AgentExecutionJob should be enqueued

  Scenario: Execute agent execution job successfully
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    And the Orchestrator is configured
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    And I process all enqueued jobs
    Then the response status should be 202
    And the lead should have agent outputs stored
    And the lead stage should advance past "queued"

  Scenario: Job validates campaign ownership
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And there is another user with a separate campaign
    And the other user has a lead
    And I have API keys configured
    When I try to execute a job for lead "#{@other_lead.id}" with campaign "#{@other_campaign.id}" and user "#{@user.id}"
    Then the job should not execute
    And the job should log an unauthorized access error

  Scenario: Job validates lead-campaign association
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And there is another user with a separate campaign
    And I have API keys configured
    When I try to execute a job for lead "#{@lead.id}" with campaign "#{@other_campaign.id}" and user "#{@user.id}"
    Then the job should not execute
    And the job should log a lead-campaign mismatch error

  Scenario: Job handles missing API keys gracefully
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I do not have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    And I process all enqueued jobs
    Then the response status should be 202
    And the job should be discarded due to ArgumentError

  Scenario: Job retries on transient errors
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    And the SEARCH agent will fail
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    And I process all enqueued jobs with errors
    Then the response status should be 202
    And the job should be retried on error

  Scenario: Job logs execution results
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    And the Orchestrator is configured
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    And I process all enqueued jobs
    Then the response status should be 202
    And the job should log successful execution

  Scenario: Sync execution when async=false
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And I have API keys configured
    And the campaign has agent configs for "SEARCH", "WRITER", "CRITIQUE", and "DESIGN"
    And the Orchestrator is configured
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=false"
    Then the response status should be 200
    And the JSON response should include "status"
    And no jobs should be enqueued
    And the lead should have agent outputs stored

