Feature: CritiqueAgent Configuration Variations
  As an authenticated user
  I want to configure CritiqueAgent with different strictness levels
  So that emails meet my quality standards

  Background:
    Given I am logged in
    And I have API keys configured
    And a campaign titled "Critique Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    And the lead has a "WRITER" agent output with email content

  Scenario: CritiqueAgent with min_score 5 (lenient)
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"min_score": 5}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use min_score 5

  Scenario: CritiqueAgent with min_score 7 (moderate)
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"min_score": 7}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use min_score 7

  Scenario: CritiqueAgent with min_score 9 (strict)
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"min_score": 9}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use min_score 9

  Scenario: CritiqueAgent with variant_selection highest_personalization_score
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"variant_selection": "highest_personalization_score"}
      """
    And the lead has a "WRITER" agent output with variants
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use highest_personalization_score selection

  Scenario: CritiqueAgent with variant_selection highest_overall_score (default)
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"variant_selection": "highest_overall_score"}
      """
    And the lead has a "WRITER" agent output with variants
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use highest_overall_score selection

  Scenario: CritiqueAgent handles "None" critique
    Given the campaign has a "CRITIQUE" agent config
    And the CRITIQUE agent will return no critique
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE output should have no critique

  Scenario: CritiqueAgent limits revision count to 3
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"min_score": 9}
      """
    And the lead has a "WRITER" agent output with revision count 3
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should stop after max revisions

  Scenario: CritiqueAgent handles network errors gracefully
    Given the campaign has a "CRITIQUE" agent config
    And the CRITIQUE agent will fail
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE output should include error information

  Scenario: CritiqueAgent extracts score from critique text
    Given the campaign has a "CRITIQUE" agent config
    And the CRITIQUE agent will return critique with score
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE output should include score

  Scenario: CritiqueAgent handles empty critique
    Given the campaign has a "CRITIQUE" agent config
    And the CRITIQUE agent will return empty critique
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE output should handle empty critique

