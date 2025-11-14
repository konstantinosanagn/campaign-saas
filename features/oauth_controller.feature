Feature: OAuth Controller
  As an authenticated user
  I want to configure Gmail OAuth
  So that I can send emails via Gmail

  Background:
    Given authentication is enabled
    Given I am logged in
    Given Gmail OAuth client is configured

  Scenario: User can initiate Gmail OAuth authorization
    When I send a GET request to "/oauth/gmail/authorize"
    Then the response status should be 302
    And I should be redirected to an authorization URL
    And the session should have oauth_state
    And the session should have oauth_user_id

  Scenario: OAuth authorization fails when OAuth is not configured
    Given Gmail OAuth client is not configured
    When I send a GET request to "/oauth/gmail/authorize"
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message
    And the error message should include "Gmail OAuth is not configured"

  Scenario: OAuth authorization handles errors gracefully
    Given GmailOauthService will raise an error when getting authorization URL
    When I send a GET request to "/oauth/gmail/authorize"
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message

  Scenario: OAuth callback succeeds with valid code
    Given GmailOauthService will return exchange result true
    And I have oauth_state in session
    And I have oauth_user_id in session
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see a success flash message
    And the session oauth_state should be cleared
    And the session oauth_user_id should be cleared
    And the user should have gmail_access_token set
    And the user should have gmail_refresh_token set

  Scenario: OAuth callback fails with error parameter
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"error": "access_denied"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message
    And the error message should include "OAuth authorization failed"

  Scenario: OAuth callback fails without code
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message
    And the error message should include "No authorization code received"

  Scenario: OAuth callback handles user ID mismatch
    Given I have oauth_user_id in session with value 999
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And a warning should be logged about user ID mismatch

  Scenario: OAuth callback fails when token exchange fails
    Given GmailOauthService will return exchange result false
    And I have oauth_state in session
    And I have oauth_user_id in session
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message
    And the error message should include "Failed to configure Gmail OAuth"

  Scenario: OAuth callback handles exceptions during token exchange
    Given GmailOauthService will raise an error during token exchange
    And I have oauth_state in session
    And I have oauth_user_id in session
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see an error flash message
    And the error message should include "OAuth callback failed"

  Scenario: User can revoke Gmail OAuth
    Given I have Gmail OAuth configured
    When I send a DELETE request to "/oauth/gmail/revoke"
    Then the response status should be 302
    And I should be redirected to the home page
    And I should see a success flash message
    And the user's gmail_access_token should be nil
    And the user's gmail_refresh_token should be nil
    And the user's gmail_token_expires_at should be nil

  Scenario: OAuth authorization stores state in session for security
    When I send a GET request to "/oauth/gmail/authorize"
    Then the session should have oauth_state
    And the oauth_state should be a random hex string
    And the session should have oauth_user_id
    And the oauth_user_id should match the current user ID

  Scenario: OAuth callback clears session after successful exchange
    Given GmailOauthService will return exchange result true
    And I have oauth_state in session
    And I have oauth_user_id in session
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the session should not have oauth_state
    And the session should not have oauth_user_id

  Scenario: OAuth callback preserves session on error
    Given GmailOauthService will raise an error during token exchange
    And I have oauth_state in session
    And I have oauth_user_id in session
    When I send a GET request to "/oauth/gmail/callback" with params:
      """
      {"code": "valid_code"}
      """
    Then the session may still have oauth_state
    And the session may still have oauth_user_id

