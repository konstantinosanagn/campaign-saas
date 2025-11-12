Feature: Email sender service Gmail API integration and environment handling
  As an authenticated user
  I want to ensure that emails can be sent through Gmail API
  So that I can reach out to leads

  Background:
    Given a user exists
    And I am logged in

  Scenario: send_via_gmail_api uses VERIFY_NONE in development environment
    Given a campaign titled "Dev Gmail API Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And Rails environment is development
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token "dev-token"
    And Gmail API will respond with 200 and body '{"id":"dev-msg"}'
    When I attempt to send email for my lead
    Then the last email send should have succeeded
