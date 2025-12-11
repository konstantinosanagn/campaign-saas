@webmock_enabled
Feature: Google OAuth Token Refresher
  As a system
  I want to ensure Gmail access tokens are refreshed when needed
  So that users can always send emails via Gmail

  Background:
    Given a user with a valid Gmail refresh token

  Scenario: Token does not need refresh
    Given the user's Gmail access token is valid and not expiring soon
    When the token refresher runs
    Then the user's Gmail access token should not be updated

  Scenario: Token needs refresh and refresh is successful
    Given the user's Gmail access token is expired or expiring soon
    And the Google token endpoint returns a new access token
    When the token refresher runs
    Then the user's Gmail access token should be updated
    And the token expiry should be updated

  Scenario: Token refresh fails with authorization error
    Given the user's Gmail access token is expired or expiring soon
    And the Google token endpoint returns an authorization error
    When the token refresher runs
    Then a Gmail authorization error should be raised

  Scenario: Token refresh fails with other error
    Given the user's Gmail access token is expired or expiring soon
    And the Google token endpoint returns a non-authorization error
    When the token refresher runs
    Then a generic token refresh error should be raised
