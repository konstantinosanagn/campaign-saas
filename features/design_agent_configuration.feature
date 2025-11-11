Feature: DesignAgent Configuration Variations
  As an authenticated user
  I want to configure DesignAgent with different formatting options
  So that emails are formatted according to my preferences

  Background:
    Given I am logged in
    And I have API keys configured
    And a campaign titled "Design Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "WRITER" agent output with email content

  Scenario: DesignAgent with format plain_text
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"format": "plain_text"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN output should not include markdown formatting

  Scenario: DesignAgent with format formatted (default)
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"format": "formatted"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN output should include formatted_email

  Scenario: DesignAgent with allow_bold false
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_bold": false}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt without bold instructions

  Scenario: DesignAgent with allow_bold true (default)
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_bold": true}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with bold instructions

  Scenario: DesignAgent with allow_italic false
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_italic": false}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt without italic instructions

  Scenario: DesignAgent with allow_italic true (default)
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_italic": true}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with italic instructions

  Scenario: DesignAgent with allow_bullets false
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_bullets": false}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt without bullet instructions

  Scenario: DesignAgent with allow_bullets true (default)
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"allow_bullets": true}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with bullet instructions

  Scenario: DesignAgent with cta_style button
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"cta_style": "button"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with button-style CTA instructions

  Scenario: DesignAgent with cta_style link (default)
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"cta_style": "link"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with link-style CTA instructions

  Scenario: DesignAgent with font_family serif
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"font_family": "serif"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with serif font guidance

  Scenario: DesignAgent with font_family sans-serif
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"font_family": "sans-serif"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with sans-serif font guidance

  Scenario: DesignAgent handles empty email content
    Given the lead has a "WRITER" agent output without email content
    And the campaign has a "DESIGN" agent config
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN output should have empty formatted_email

  Scenario: DesignAgent handles API errors gracefully
    Given the campaign has a "DESIGN" agent config
    And the DESIGN agent will fail
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN output should include error information

  Scenario: DesignAgent with multiple configuration options
    Given the campaign has a "DESIGN" agent config with settings:
      """
      {"format": "formatted", "allow_bold": false, "allow_italic": true, "allow_bullets": false, "cta_style": "button", "font_family": "serif"}
      """
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output
    And the DESIGN agent should build prompt with combined configuration

