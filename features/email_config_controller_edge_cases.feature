Feature: EmailConfigController Edge Cases
  As an authenticated user
  I want email configuration to handle edge cases correctly
  So that the application works correctly in all scenarios

  Background:
    Given I am logged in
    And authentication is enabled

  Scenario: EmailConfigController show handles GmailOauthService errors gracefully
    Given GmailOauthService will raise an error when checking oauth_configured
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And the JSON response should include "email"

  Scenario: EmailConfigController show returns false when OAuth service fails
    Given GmailOauthService will raise an error when checking oauth_configured
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And a warning should be logged about Gmail OAuth service error

  Scenario: EmailConfigController update handles validation errors
    Given I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": ""}
      """
    Then the response status should be 422
    And the JSON response should include "error" with "Email is required"

  Scenario: EmailConfigController update handles missing email
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {}
      """
    Then the response status should be 422
    And the JSON response should include "error" with "Email is required"

  Scenario: EmailConfigController update handles nil email
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": null}
      """
    Then the response status should be 422
    And the JSON response should include "error" with "Email is required"

  Scenario: EmailConfigController update handles whitespace-only email
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "   "}
      """
    Then the response status should be 422
    And the JSON response should include "error" with "Email is required"

  Scenario: EmailConfigController update handles GmailOauthService errors gracefully
    Given GmailOauthService will raise an error when checking oauth_configured
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "newemail@example.com"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And the JSON response should include "email" with "newemail@example.com"
    And a warning should be logged about Gmail OAuth service error

  Scenario: EmailConfigController update returns false when OAuth service fails
    Given GmailOauthService will raise an error when checking oauth_configured
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "newemail@example.com"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And the JSON response should include "email" with "newemail@example.com"

  Scenario: EmailConfigController update handles user validation errors
    Given the user model will raise validation errors
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "invalid-email"}
      """
    Then the response status should be 422
    And the JSON response should include "error"
    And the error should include validation messages

  Scenario: EmailConfigController update strips whitespace from email
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "  user@example.com  "}
      """
    Then the response status should be 200
    And the JSON response should include "email" with "user@example.com"
    And the user's send_from_email should be "user@example.com"

  Scenario: EmailConfigController show checks send_from_email user OAuth when different
    Given there is another user with email "other@example.com"
    And I set my send_from_email to "other@example.com"
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true
    And the JSON response should include "email" with "other@example.com"
    And an info log should be recorded about using OAuth from send_from_email user

  Scenario: EmailConfigController update checks send_from_email user OAuth when different
    Given there is another user with email "other@example.com"
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "other@example.com"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true
    And the JSON response should include "email" with "other@example.com"
    And an info log should be recorded about using OAuth from send_from_email user

  Scenario: EmailConfigController show returns false when send_from_email user does not exist
    Given I set my send_from_email to "nonexistent@example.com"
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And the JSON response should include "email" with "nonexistent@example.com"

  Scenario: EmailConfigController update returns false when send_from_email user does not exist
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "nonexistent@example.com"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false
    And the JSON response should include "email" with "nonexistent@example.com"

  Scenario: EmailConfigController show handles OAuth check for current user when send_from_email matches
    Given GmailOauthService will report oauth_configured for current user as true
    And I set my send_from_email to my email
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true
    And the JSON response should include "email"

  Scenario: EmailConfigController update handles OAuth check for current user when send_from_email matches
    Given GmailOauthService will report oauth_configured for current user as true
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "#{@user.email}"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true
    And the JSON response should include "email"

