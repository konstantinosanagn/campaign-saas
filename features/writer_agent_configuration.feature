Feature: WriterAgent Configuration Variations
  As an authenticated user
  I want to configure WriterAgent with different writing styles
  So that emails match my brand voice and goals

  Background:
    Given I am logged in
    And I have API keys configured
    And a campaign titled "Writer Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "searched"
    And the lead has a "SEARCH" agent output

  Scenario: WriterAgent with tone formal
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"tone": "formal"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use formal tone

  Scenario: WriterAgent with tone professional (default)
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"tone": "professional"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use professional tone

  Scenario: WriterAgent with tone friendly
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"tone": "friendly"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use friendly tone

  Scenario: WriterAgent with sender_persona founder
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"sender_persona": "founder"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use founder persona

  Scenario: WriterAgent with sender_persona sales
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"sender_persona": "sales"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use sales persona

  Scenario: WriterAgent with sender_persona customer_success
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"sender_persona": "customer_success"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use customer_success persona

  Scenario: WriterAgent with email_length very_short
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"email_length": "very_short"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use very_short length

  Scenario: WriterAgent with email_length short (default)
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"email_length": "short"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use short length

  Scenario: WriterAgent with email_length standard
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"email_length": "standard"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use standard length

  Scenario: WriterAgent with personalization_level low
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"personalization_level": "low"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use low personalization

  Scenario: WriterAgent with personalization_level medium (default)
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"personalization_level": "medium"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use medium personalization

  Scenario: WriterAgent with personalization_level high
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"personalization_level": "high"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use high personalization

  Scenario: WriterAgent with primary_cta_type book_call
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"primary_cta_type": "book_call"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use book_call CTA

  Scenario: WriterAgent with primary_cta_type get_reply
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"primary_cta_type": "get_reply"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use get_reply CTA

  Scenario: WriterAgent with primary_cta_type get_click
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"primary_cta_type": "get_click"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use get_click CTA

  Scenario: WriterAgent with cta_softness soft
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"cta_softness": "soft"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use soft CTA

  Scenario: WriterAgent with cta_softness balanced (default)
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"cta_softness": "balanced"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use balanced CTA

  Scenario: WriterAgent with cta_softness direct
    Given the campaign has a "WRITER" agent config with settings:
      """
      {"cta_softness": "direct"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER agent should use direct CTA

  Scenario: WriterAgent handles API errors gracefully
    Given the campaign has a "WRITER" agent config
    And the WRITER agent will fail
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER output should include error information

