Feature: ApplicationController
  As a user
  I want the application to handle edge cases correctly
  So that the application works correctly in all scenarios

  Background:
    Given authentication is enabled

  Scenario: ApplicationController uses custom login path in production
    Given the application is in production mode
    When I check the new_user_session_path
    Then it should return "/login"
    And it should not return "/users/sign_in"

  Scenario: ApplicationController uses custom signup path in production
    Given the application is in production mode
    When I check the new_user_registration_path
    Then it should return "/signup"
    And it should not return "/users/sign_up"

  Scenario: ApplicationController uses default paths in development
    Given the application is in development mode
    When I check the new_user_session_path
    Then it should return "/users/sign_in"
    And I check the new_user_registration_path
    Then it should return "/users/sign_up"

  Scenario: ApplicationController ensures default API keys in development
    Given the application is in development mode
    And no users exist
    When I create a user with email "devuser@example.com"
    And I visit the home page
    Then the user should have llm_api_key set
    And the user should have tavily_api_key set
    And the llm_api_key should be the default dev key
    And the tavily_api_key should be the default dev key

  Scenario: ApplicationController does not set API keys in production
    Given the application is in production mode
    And no users exist
    When I create a user with email "produser@example.com"
    And I visit the home page
    Then the user should not have llm_api_key set
    And the user should not have tavily_api_key set

  Scenario: ApplicationController normalizes user from session
    Given a user exists with email "user@example.com"
    And I am logged in as "user@example.com"
    When I check the current_user
    Then it should be a User object
    And it should have email "user@example.com"

  Scenario: ApplicationController handles nil user gracefully
    Given I am not logged in
    When I check the current_user
    Then it should be nil

  Scenario: ApplicationController does not set API keys if user already has them
    Given the application is in development mode
    And a user exists with email "devuser@example.com"
    And the user has llm_api_key "custom-key"
    And the user has tavily_api_key "custom-tavily-key"
    When I visit the home page
    Then the user's llm_api_key should be "custom-key"
    And the user's tavily_api_key should be "custom-tavily-key"

  Scenario: ApplicationController sets only missing API keys in development
    Given the application is in development mode
    And a user exists with email "devuser@example.com"
    And the user has llm_api_key "custom-key"
    And the user does not have tavily_api_key
    When I visit the home page
    Then the user's llm_api_key should be "custom-key"
    And the user's tavily_api_key should be the default dev key

  Scenario: ApplicationController sets API keys only for authenticated users
    Given the application is in development mode
    And I am not logged in
    When I visit the home page
    Then no API keys should be set

  Scenario: ApplicationController normalizes user from hash with id
    Given a user exists with email "user@example.com"
    And I have a user hash with id
    When I check the normalized user
    Then it should be a User object
    And it should have email "user@example.com"

  Scenario: ApplicationController normalizes user from hash with string id
    Given a user exists with email "user@example.com"
    And I have a user hash with string id
    When I check the normalized user
    Then it should be a User object
    And it should have email "user@example.com"

  Scenario: ApplicationController returns nil for invalid user hash
    Given I have an invalid user hash
    When I check the normalized user
    Then it should be nil

