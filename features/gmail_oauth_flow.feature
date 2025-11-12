Feature: Gmail OAuth authorization and token management
  As an authenticated user
  I want to authorize Gmail access and manage OAuth tokens
  So that I can securely send emails through my Gmail account

  Background:
    Given a user exists
    And I am logged in

  Scenario: OAuth authorize redirects to Google when configured
    Given Gmail OAuth client is configured
    And GmailOauthService will return authorization url "https://accounts.google.test/auth"
    When I send a GET request to "/oauth/gmail/authorize"
    Then the response status should be 302

  Scenario: OAuth authorize redirects to root when not configured
    Given Gmail OAuth client is not configured
    When I send a GET request to "/oauth/gmail/authorize"
    Then the response status should be 302

  Scenario: OAuth callback handles error param
    When I send a GET request to "/oauth/gmail/callback?error=access_denied"
    Then the response status should be 302

  Scenario: OAuth callback handles missing code
    When I send a GET request to "/oauth/gmail/callback"
    Then the response status should be 302

  Scenario: OAuth callback handles exchange success and failure
    Given GmailOauthService will return exchange result true
    When I send a GET request to "/oauth/gmail/callback?code=testcode"
    Then the response status should be 302

    Given GmailOauthService will return exchange result false
    When I send a GET request to "/oauth/gmail/callback?code=testcode"
    Then the response status should be 302

  Scenario: GmailOauthService.authorization_url raises when env missing and returns when configured
    Given Gmail OAuth client is not configured
    When I attempt to get authorization url for GmailOauthService
    Then the last operation should have raised an error

    Given Gmail OAuth client is configured
    And Signet client will provide authorization uri "https://accounts.google.test/auth"
    When I attempt to get authorization url for GmailOauthService
    Then the last operation should not have raised an error

  Scenario: GmailOauthService.exchange_code_for_tokens sets tokens on user when client returns tokens
    Given Gmail OAuth client is configured
    And Signet exchange will succeed with tokens
    When I exchange code "exchange123" for tokens for my user
    Then the last operation should not have raised an error

  Scenario: GmailOauthService.exchange_code_for_tokens handles expires_in and missing refresh_token
    Given Gmail OAuth client is configured
    And Signet exchange will succeed with expires_in and no refresh_token
    When I exchange code "code-expires-in" for tokens for my user
    Then the last operation should not have raised an error

  Scenario: GmailOauthService.refresh_access_token refreshes when token expired
    Given Gmail OAuth client is configured
    And Signet refresh will succeed with tokens
    Given a user exists
    When I set the user's gmail_refresh_token to "refresh-zzz"
    And I set the user's gmail_token_expires_at to "2000-01-01 00:00:00"
    When I request a valid access token for my user
    Then the last operation should not have raised an error

  Scenario: GmailOauthService.exchange_code_for_tokens handles exchange failure gracefully
    Given Gmail OAuth client is configured
    And Signet exchange will fail
    When I exchange code "bad-code" for tokens for my user
    Then the last operation should have returned false

  Scenario: valid_access_token returns nil when user has no refresh token
    Given a user exists
    When I request a valid access token for my user
    Then the last result should be nil

  Scenario: authorization_url builds redirect from MAILER_HOST without protocol
    Given Gmail OAuth client is configured
    And I set ENV var "MAILER_HOST" to "localhost:4000"
    And Signet client will provide authorization uri "https://accounts.google.test/auth"
    When I attempt to get authorization url for GmailOauthService
    Then the last operation should not have raised an error

  Scenario: GmailOauthService.refresh_access_token handles refresh failure gracefully
    Given Gmail OAuth client is configured
    And Signet refresh will fail
    Given a user exists
    When I set the user's gmail_refresh_token to "refresh-zzz"
    And I set the user's gmail_token_expires_at to "2000-01-01 00:00:00"
    When I request a valid access token for my user
    Then the last result should be nil
