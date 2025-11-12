Feature: EmailSenderService behavior with handling multiple leads and batch operations

  Background:
    Given a user exists
    And I am logged in

  Scenario: EmailSenderService sends emails to multiple ready leads
    Given a campaign titled "Multi Lead Campaign" exists for me
    And the campaign has a lead with email "lead1@example.com"
    And the lead with email "lead1@example.com" has a "DESIGN" agent output with email content
    And the lead with email "lead1@example.com" has stage "designed"
    And the campaign has a lead with email "lead2@example.com"
    And the lead with email "lead2@example.com" has a "WRITER" agent output with email content
    And the lead with email "lead2@example.com" has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 2

  Scenario: EmailSenderService skips leads not at designed or completed stage
    Given a campaign titled "Mixed Stage Campaign" exists for me
    And the campaign has a lead with email "queued@example.com"
    And the lead with email "queued@example.com" has stage "queued"
    And the campaign has a lead with email "processing@example.com"
    And the lead with email "processing@example.com" has stage "processing"
    And the campaign has a lead with email "ready@example.com"
    And the lead with email "ready@example.com" has a "DESIGN" agent output with email content
    And the lead with email "ready@example.com" has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1

  Scenario: EmailSenderService tracks failures when some leads fail to send
    Given a campaign titled "Partial Failure Campaign" exists for me
    And the campaign has a lead with email "success@example.com"
    And the lead with email "success@example.com" has a "DESIGN" agent output with email content
    And the lead with email "success@example.com" has stage "designed"
    And the campaign has a lead with email "fail@example.com"
    And the lead with email "fail@example.com" has a "DESIGN" agent output with email content
    And the lead with email "fail@example.com" has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will fail for lead "fail@example.com"
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1
    And the send result should have failed 1

  Scenario: EmailSenderService returns zero sent for campaign with no ready leads
    Given a campaign titled "No Ready Leads Campaign" exists for me
    And the campaign has a lead with email "notready@example.com"
    And the lead with email "notready@example.com" has stage "queued"
    When I run EmailSenderService for the campaign
    Then the send result should have sent 0
    And the send result should have failed 0

  Scenario: EmailSenderService logs and continues when one lead throws exception
    Given a campaign titled "Exception Campaign" exists for me
    And the campaign has a lead with email "lead1@example.com"
    And the lead with email "lead1@example.com" has a "DESIGN" agent output with email content
    And the lead with email "lead1@example.com" has stage "designed"
    And the campaign has a lead with email "lead2@example.com"
    And the lead with email "lead2@example.com" has a "DESIGN" agent output with email content
    And the lead with email "lead2@example.com" has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise exception for lead "lead1@example.com"
    When I run EmailSenderService for the campaign
    Then the send result should have sent 1
    And the send result should have failed 1

  Scenario: EmailSenderService tracks multiple error details in results
    Given a campaign titled "Multiple Errors Campaign" exists for me
    And the campaign has a lead with email "error1@example.com"
    And the lead with email "error1@example.com" has a "DESIGN" agent output with email content
    And the lead with email "error1@example.com" has stage "designed"
    And the campaign has a lead with email "error2@example.com"
    And the lead with email "error2@example.com" has a "DESIGN" agent output with email content
    And the lead with email "error2@example.com" has stage "designed"
    And SMTP environment is configured
    And CampaignMailer delivery will raise exception for lead "error1@example.com"
    And CampaignMailer delivery will raise exception for lead "error2@example.com"
    When I run EmailSenderService for the campaign
    Then the send result should have sent 0
    And the send result should have failed 2
