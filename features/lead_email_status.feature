Feature: Lead email status methods
  As a developer
  I want to have clear and reliable methods that indicate the current email status for each lead and handle sending each lead's email

  Scenario: Lead not found when sending email
    Given there is no lead with id 9999
    When the email sending job is performed for lead id 9999
    Then a warning log should include "Lead 9999 not found; skipping"

  Scenario: Temporary email error occurs
    Given a lead exists with id 1
    And sending email for lead id 1 will raise a TemporaryEmailError with message "Network timeout"
    When the email sending job is performed for lead id 1
    Then the lead's email_status should be "failed"
    And the lead's last_email_error_message should include "Network timeout"
    And a warning log should include "Retrying after temporary error for lead_id=1: Network timeout"

  Scenario: Permanent email error occurs
    Given a lead exists with id 2
    And sending email for lead id 2 will raise a PermanentEmailError with message "Authentication failed"
    When the email sending job is performed for lead id 2
    Then the lead's email_status should be "failed"
    And the lead's last_email_error_message should include "Authentication failed"
    And an error log should include "Permanent email failure for lead_id=2: Authentication failed"

  Scenario: Lead email_sent? returns true when status is sent
    Given a lead with email status "sent"
    When I check if the lead email was sent
    Then the result should be true

  Scenario: Lead email_sending? returns true when status is sending
    Given a lead with email status "sending"
    When I check if the lead email is sending
    Then the result should be true

  Scenario: Lead email_failed? returns true when status is failed
    Given a lead with email status "failed"
    When I check if the lead email failed
    Then the result should be true

  Scenario: Lead email_not_scheduled? returns true when status is not_scheduled
    Given a lead with email status "not_scheduled"
    When I check if the lead email is not scheduled
    Then the result should be true

  Scenario: Attempt to send email when lead is not ready
    Given a lead exists with id 11, stage "queued", and no email content
    When the email sending job is performed for lead id 11
    Then the lead's email_status should not be "sent"
    And an error log should include "Lead is not ready to send"

  Scenario: Attempt to send email when lead has no campaign user
    Given a lead exists with id 12, stage "designed", and valid email content
    And the lead's campaign has no user
    When the email sending job is performed for lead id 12
    Then the lead's email_status should not be "sent"
    And an error log should include "No email delivery method configured"

  Scenario: Use default Gmail sender when user cannot send via Gmail API
    Given a lead exists with id 14, stage "designed", and valid email content
    And the lead's campaign user cannot send via Gmail API
    And a default Gmail sender is configured and can send
    When the email sending job is performed for lead id 14
    Then the lead's email_status should be "sent"
    And an info log should include "using default sender"

  Scenario: Handle generic error during email sending
    Given a lead exists with id 17, stage "designed", and valid email content
    And sending email for lead id 17 will raise a generic error with message "Unexpected failure"
    When the email sending job is performed for lead id 17
    Then the lead's email_status should be "failed"
    And the lead's last_email_error_message should include "Unexpected failure"
    And an error log should include "Email sending failed for lead 17"

  Scenario: Handle missing email content for lead
    Given a lead exists with id 18, stage "designed", and no email content
    When the email sending job is performed for lead id 18
    Then the lead's email_status should be "failed"
    And the lead's last_email_error_message should include "Lead is not ready to send"
