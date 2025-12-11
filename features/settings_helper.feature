Feature: SettingsHelper module
  As a system
  I want to ensure that user settings can be handled correctly
  So that user has a smooth and error-free experience when interacting with their settings via the application

  Scenario: Get setting by symbol and string key
    Given a settings hash with "tone" set to "friendly"
    Then get_setting with :tone returns "friendly"
    And get_setting with "tone" returns "friendly"

  Scenario: Dig nested setting with mixed keys
    Given a nested settings hash with brand_voice.tone set to "formal"
    Then dig_setting with :brand_voice, :tone returns "formal"
    And dig_setting with "brand_voice", "tone" returns "formal"

  Scenario: Get setting with default fallback
    Given a settings hash with no "missing" key
    Then get_setting_with_default with :missing and default "default_value" returns "default_value"

  Scenario: Get multiple settings at once
    Given a settings hash with "a" set to 1 and :b set to 2
    Then get_settings with :a, :b returns a hash with a: 1 and b: 2

  Scenario: Check if setting is present
    Given a settings hash with "present" set to "yes" and "empty" set to ""
    Then setting_present? with :present returns true
    And setting_present? with :empty returns false
    And setting_present? with :missing returns false
