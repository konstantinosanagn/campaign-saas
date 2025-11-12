Feature: EmailSenderService basic operations including lead readiness checks and basic sending

  Background:
    Given a user exists
    And I am logged in

  Scenario: EmailSenderService sends email via Gmail API when OAuth and access token present
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService will return valid access token "access-token-123"
    And Gmail API will respond with 200 and body '{"id":"msg-123"}'
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService falls back to WRITER output and uses SMTP password settings
    Given a campaign titled "SMTP Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as false
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then an email should be delivered to "alice@example.com"

  Scenario: send_email_for_lead returns error when lead not ready
    Given a campaign titled "Not Ready Campaign" exists for me
    And the campaign has a lead with email "notready@example.com"
    And the lead with email "notready@example.com" has stage "queued"
    When I attempt to send email for lead "notready@example.com"
    Then the last email send should have failed with message containing "not ready"

  Scenario: send_email_for_lead fails when email content missing despite designed stage
    Given a campaign titled "NoContent Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output without email content
    When I attempt to send email for my lead
    Then the last email send should have failed with message containing "not ready"

  Scenario: lead_ready? returns false when lead has no agent output
    Given a campaign titled "No Output Campaign" exists for me
    And the campaign has a lead with email "nooutput@example.com"
    And the lead with email "nooutput@example.com" has stage "designed"
    When I attempt to send email for lead "nooutput@example.com"
    Then the last email send should have failed with message containing "not ready"

  Scenario: lead_ready? returns true with WRITER output when DESIGN is missing
    Given a campaign titled "Writer Only Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And the lead does not have a "DESIGN" agent output
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService sends to lead at completed stage
    Given a campaign titled "Completed Stage Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "completed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: send_email_for_lead returns error when lead has no campaign
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I remove campaign from lead
    And I attempt to send email for my lead
    Then the last email send should have failed with message containing "valid campaign"

  Scenario: send_email_for_lead returns error when campaign has no user
    Given a campaign titled "No User Campaign" exists for me
    And a lead exists for my campaign
    When I remove user from campaign
    And I attempt to send email for my lead
    Then the last email send should have failed with message containing "valid campaign"

  Scenario: EmailSenderService raises error when lead has no email content
    Given a campaign titled "No Content Error Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output without email content
    And the lead has stage "designed"
    And SMTP environment is configured
    When I attempt to send email for my lead
    Then the last email send should have failed with message containing "not ready"

  Scenario: send_email_for_lead returns success true when email sent successfully
    Given a campaign titled "Success Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded
    And the success message should contain "Email sent successfully"
