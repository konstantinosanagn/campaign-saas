Feature: EmailSenderService error handling for various failure scenarios

  Background:
    Given a user exists
    And I am logged in

  Scenario: send_email_for_lead handles SMTP delivery errors gracefully
    Given a campaign titled "Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise an SMTP error
    When I attempt to send email for my lead
    Then the last email send should have failed with an SMTP error

  Scenario: EmailSenderService handles Gmail API error gracefully
    Given a campaign titled "Gmail Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token "access-token-500"
    And Gmail API will respond with 500 and body '{"error":"server"}'
    When I run EmailSenderService for the campaign
    Then the send result should have sent 0

  Scenario: EmailSenderService handles connection timeout error gracefully
    Given a campaign titled "Timeout Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise a connection timeout error
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles SSL error gracefully
    Given a campaign titled "SSL Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise an SSL error
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles missing SMTP configuration
    Given a campaign titled "No SMTP Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as false
    And SMTP is not configured
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: send_via_gmail_api raises error when HTTP request fails
    Given a campaign titled "Gmail HTTP Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token "access-token-http-error"
    And Gmail API HTTP request will raise connection error
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles Net::SMTPAuthenticationError with response details
    Given a campaign titled "SMTP Auth Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise SMTP authentication error with response
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles Net::SMTPError with response
    Given a campaign titled "SMTP Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise Net::SMTPError
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles Errno::ECONNREFUSED error
    Given a campaign titled "Connection Refused Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise connection refused error
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: EmailSenderService handles Timeout::Error
    Given a campaign titled "Timeout Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise Timeout::Error
    When I attempt to send email for my lead
    Then the last email send should have failed with an error

  Scenario: send_via_gmail_api handles non-200 response codes
    Given a campaign titled "Gmail 400 Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token "bad-request-token"
    And Gmail API will respond with 400 and body '{"error":"bad request"}'
    When I attempt to send email for my lead
    Then the last email send should have failed with an error
