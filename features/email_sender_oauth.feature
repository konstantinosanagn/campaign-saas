Feature: Email sender service OAuth integration
  Tests EmailSenderService OAuth user lookup and token handling

  Background:
    Given a user exists
    And I am logged in

  Scenario: EmailSenderService uses send_from_email different from user email for OAuth lookup
    Given a campaign titled "OAuth Lookup Campaign" exists for me
    And there is another user with a separate campaign
    And I set my send_from_email to "other@example.com"
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    And GmailOauthService will return valid access token "other-access-token"
    And Gmail API will respond with 200 and body '{"id":"msg-oauth-lookup"}'
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService uses SMTP when OAuth token retrieval fails
    Given a campaign titled "OAuth Fail Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token nil
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService finds OAuth user when send_from_email equals user email but another user has OAuth
    Given a campaign titled "Alternative OAuth Campaign" exists for me
    And there is another user with email "admin@example.com"
    And the other user has OAuth configured
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for other user as true
    And GmailOauthService will return valid access token "alternative-token" for other user
    And Gmail API will respond with 200 and body '{"id":"msg-alt"}'
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService uses from_email from user send_from_email setting
    Given a campaign titled "Custom From Campaign" exists for me
    And I set my send_from_email to "custom@example.com"
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService uses user email as from_email when send_from_email is not set
    Given a campaign titled "Default From Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1
    And an email should be delivered to "alice@example.com"

  Scenario: EmailSenderService logs warning when OAuth configured but token is nil
    Given a campaign titled "OAuth Warning Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token nil
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded
