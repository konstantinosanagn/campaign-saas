Feature: Gmail OAuth configuration and status checks

  Background:
    Given a user exists
    And I am logged in

  Scenario: OAuth status reports not configured when env missing
    Given Gmail OAuth client is not configured
    When I send a GET request to "/api/v1/oauth_status"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false

  Scenario: OAuth status reports configured when env present
    Given Gmail OAuth client is configured
    When I send a GET request to "/api/v1/oauth_status"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true

  Scenario: Email config show returns oauth_configured true for current user
    Given GmailOauthService will report oauth_configured for current user as true
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true

  Scenario: Email config show falls back to send_from_email user's oauth status
    Given there is another user with a separate campaign
    And I am logged in
    And I set my send_from_email to "other@example.com"
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true

  Scenario: Email config show handles GmailOauthService errors gracefully
    Given GmailOauthService will raise error when checking oauth_configured
    When I send a GET request to "/api/v1/email_config"
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with false

  Scenario: Email config update returns error when email missing
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {}
      """
    Then the response status should be 422
    And the JSON response should include "error" with "Email is required"

  Scenario: Email config update returns oauth_configured true when send_from_email user has OAuth
    Given there is another user with a separate campaign
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    When I send a PUT request to "/api/v1/email_config" with JSON:
      """
      {"email": "other@example.com"}
      """
    Then the response status should be 200
    And the JSON response should include "oauth_configured" with true
