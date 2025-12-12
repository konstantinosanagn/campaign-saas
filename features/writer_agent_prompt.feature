Feature: Writer Agent prompt and error handling coverage
  As a developer
  I want to ensure WriterAgent covers all prompt and error branches
  So that all logic is robustly tested

  Scenario: previous_critique is present
    Given WriterAgent is initialized with previous_critique feedback
    When the agent builds the prompt
    Then the prompt should include the critique feedback section

  Scenario: previous_critique is not present
    Given WriterAgent is initialized without previous_critique
    When the agent builds the prompt
    Then the prompt should not include the critique feedback section

  Scenario: sources are present
    Given WriterAgent is initialized with sources
    When the agent builds the prompt
    Then the prompt should include the sources section

  Scenario: sources are empty
    Given WriterAgent is initialized with no sources
    When the agent builds the prompt
    Then the prompt should include the limited sources note

  Scenario: focus_areas are present
    Given WriterAgent is initialized with focus_areas
    When the agent builds the prompt
    Then the prompt should include the focus areas section

  Scenario: focus_areas are empty
    Given WriterAgent is initialized with no focus_areas
    When the agent builds the prompt
    Then the prompt should not include the focus areas section
