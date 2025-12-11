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

  Scenario: CritiqueAgent with strictness level lenient
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"strictness": "lenient", "min_score": 6}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use lenient strictness

  Scenario: CritiqueAgent with strictness level moderate
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"strictness": "moderate", "min_score": 6}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use moderate strictness

  Scenario: CritiqueAgent with strictness level strict
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"strictness": "strict", "min_score": 6}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use strict strictness

  Scenario: CritiqueAgent with default strictness (no setting)
    Given the campaign has a "CRITIQUE" agent config with settings:
      """
      {"min_score": 6}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output
    And the CRITIQUE agent should use default strictness

  Scenario: extract_feedback_text returns empty string for nil input
    Given I have a CritiqueAgent instance
    When I extract feedback text from nil
    Then the result should be an empty string

  Scenario: extract_feedback_text returns empty string for empty input
    Given I have a CritiqueAgent instance
    When I extract feedback text from an empty string
    Then the result should be an empty string

  Scenario: extract_feedback_text removes score lines
    Given I have a CritiqueAgent instance
    When I extract feedback text from:
      """
      Score: 7/10
      This email is clear and concise.
      """
    Then the result should be:
      """
      This email is clear and concise.
      """

  Scenario: should_rewrite? returns false for blank critique_text
    Given I have a CritiqueAgent instance
    When I check should_rewrite? with policy "always", meets_min_score true, and blank critique_text
    Then the should_rewrite? result should be false

  Scenario: should_rewrite? returns false for policy never
    Given I have a CritiqueAgent instance
    When I check should_rewrite? with policy "never", meets_min_score false, and critique_text "Needs work"
    Then the should_rewrite? result should be false

  Scenario: should_rewrite? returns true for policy always
    Given I have a CritiqueAgent instance
    When I check should_rewrite? with policy "always", meets_min_score true, and critique_text "Needs work"
    Then the should_rewrite? result should be true

  Scenario: should_rewrite? returns !meets_min_score for rewrite_if_bad
    Given I have a CritiqueAgent instance
    When I check should_rewrite? with policy "rewrite_if_bad", meets_min_score false, and critique_text "Needs work"
    Then the should_rewrite? result should be true
    When I check should_rewrite? with policy "rewrite_if_bad", meets_min_score true, and critique_text "Needs work"
    Then the should_rewrite? result should be false

  Scenario: rewrite_email returns rewritten text and logs completion
    Given I have a CritiqueAgent instance with a stubbed API response "Rewritten email text"
    When I rewrite email with content "Original email", critique_text "Improve CTA", and settings "{}"
    Then the rewrite_email result should be "Rewritten email text"
    And the log should include "Rewrite completed"

  Scenario: rewrite_email logs error and returns nil on exception
    Given I have a CritiqueAgent instance that raises an error on API call
    When I rewrite email with content "Original email", critique_text "Improve CTA", and settings "{}"
    Then the rewrite_email result should be nil
    And the log should include "Rewrite error"

  Scenario: log outputs to Rails logger if available
    Given Rails logger is available
    And I have a CritiqueAgent instance
    When I log the message "Test log"
    Then Rails.logger should receive info with "[CritiqueAgent] Test log"

  Scenario: log outputs to stdout if Rails logger is not available
    Given Rails logger is not available
    And I have a CritiqueAgent instance
    When I log the message "Test log"
    Then stdout should include "[CritiqueAgent] Test log"

  Scenario: CritiqueAgent handles network error in critique method
    Given I have a CritiqueAgent instance that raises an error on critique
    When I run critique with email content "Test email"
    Then the critique result should have network error details

  Scenario: extract_score_from_critique returns explicit score
    Given I have a CritiqueAgent instance
    When I extract score from critique text "Score: 8/10" with default 5
    Then the extracted score should be 8

  Scenario: extract_score_from_critique returns default_score for nil or empty
    Given I have a CritiqueAgent instance
    When I extract score from critique text nil with default 7
    Then the extracted score should be 7
    When I extract score from critique text "" with default 6
    Then the extracted score should be 6

  Scenario: extract_score_from_critique returns default+1 for 'None' feedback
    Given I have a CritiqueAgent instance
    When I extract score from critique text "Score: 5/10\nNone" with default 5
    Then the extracted score should be 5
    When I extract score from critique text "None" with default 9
    Then the extracted score should be 10

  Scenario: extract_score_from_critique fallback for empty feedback
    Given I have a CritiqueAgent instance
    When I extract score from critique text "Score: 7/10\n" with default 7
    Then the extracted score should be 7
