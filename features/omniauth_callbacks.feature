Feature: Omniauth Callbacks
  As a user
  I want to sign in with Google using Omniauth
  So that I can access my account easily

  Background:
    Given I am on the sign in page

  Scenario: Successful Google OAuth2 sign in with complete profile
    When I sign in with Google successfully and my profile is complete
    Then I should be signed in
    And I should be redirected to the dashboard

  Scenario: Successful Google OAuth2 sign in with incomplete profile
    When I sign in with Google successfully and my profile is incomplete
    Then I should be signed in
    And I should be redirected to the complete profile page

  Scenario: Failed Google OAuth2 sign in
    When I fail to sign in with Google
    Then I should see an authentication error message
    And I should be redirected to the sign in page

  Scenario: Omniauth failure
    When the omniauth authentication fails
    Then I should see a generic authentication failed message
    And I should be redirected to the sign in page
