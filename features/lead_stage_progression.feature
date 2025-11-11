Feature: Lead Stage Progression
  As an authenticated user
  I want to track lead progression through agent stages
  So that I know the status of each lead

  Background:
    Given I am logged in

  Scenario: Lead starts at queued stage
    Given a campaign titled "Stage Test" exists for me
    When I create a lead with name "Test Lead" and email "test@example.com"
    Then the lead should have stage "queued"

  Scenario: Lead progresses to searched after SEARCH agent
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    When I run the "SEARCH" agent on the lead
    Then the lead should have stage "searched"

  Scenario: Lead progresses to written after WRITER agent
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "searched"
    When I run the "WRITER" agent on the lead
    Then the lead should have stage "written"

  Scenario: Lead progresses to critiqued after CRITIQUE agent
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have stage "critiqued"

  Scenario: Lead quality is updated after CRITIQUE agent
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a quality score

  Scenario: Lead progresses to designed after DESIGN agent
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "CRITIQUE" agent output with email content
    And the DESIGN agent will return formatted email
    When I run the "DESIGN" agent on the lead
    Then the lead should have stage "designed"

  Scenario: DESIGN agent receives CRITIQUE output
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "CRITIQUE" agent output with email content
    And the DESIGN agent will return formatted email
    When I run the "DESIGN" agent on the lead
    Then the lead should have stage "designed"
    And the lead should have agent outputs stored

  Scenario: Lead stage does not progress when agent fails
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    And the SEARCH agent will fail
    When I run the "SEARCH" agent on the lead
    Then the lead should still have stage "queued"

  Scenario: Lead stage does not progress when DESIGN agent fails
    Given a campaign titled "Stage Test" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "CRITIQUE" agent output with email content
    And the DESIGN agent will fail
    When I run the "DESIGN" agent on the lead
    Then the lead should still have stage "critiqued"

