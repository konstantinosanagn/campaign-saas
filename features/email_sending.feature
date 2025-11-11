Feature: Email Sending
  As an authenticated user
  I want to send emails to leads in my campaign
  So that I can reach out to prospects

  Background:
    Given I am logged in

  Scenario: Send emails to ready leads with DESIGN output
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "success" with true
    And the JSON response should include "sent" with 1
    And an email should be delivered to "alice@example.com"
    And the email should have subject containing "Email Campaign"
    And the email should have content from DESIGN output

  Scenario: Send emails to ready leads with COMPLETED stage
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "completed"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "success" with true
    And the JSON response should include "sent" with 1
    And an email should be delivered to "alice@example.com"

  Scenario: Send emails when no ready leads exist
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "sent" with 0
    And no emails should be delivered

  Scenario: Send emails falls back to WRITER output when DESIGN not available
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "WRITER" agent output with email content
    And the lead does not have a "DESIGN" agent output
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "success" with true
    And the JSON response should include "sent" with 1
    And an email should be delivered to "alice@example.com"
    And the email should have content from WRITER output

  Scenario: Send emails to multiple ready leads
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And the campaign has a lead with email "bob@example.com"
    And the lead with email "bob@example.com" has stage "designed"
    And the lead with email "bob@example.com" has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "sent" with 2
    And an email should be delivered to "alice@example.com"
    And an email should be delivered to "bob@example.com"

  Scenario: Send emails skips leads not at designed or completed stage
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    And the lead has a "DESIGN" agent output with email content
    And the campaign has a lead with email "bob@example.com"
    And the lead with email "bob@example.com" has stage "designed"
    And the lead with email "bob@example.com" has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "sent" with 1
    And an email should be delivered to "bob@example.com"
    And no email should be delivered to "alice@example.com"

  Scenario: Send emails skips leads without email content
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output without email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "sent" with 0
    And the JSON response should include "failed" with 0
    # Note: Leads without email content are not considered "ready" by lead_ready?
    # So they are skipped entirely (not processed, not counted as failed)
    And no emails should be delivered

  Scenario: Send emails handles SMTP errors gracefully
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And email delivery will fail
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "failed" with 1
    And the JSON response should include "errors"
    And the errors should include lead email "alice@example.com"

  Scenario: Send emails uses campaign user email as from address
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And an email should be delivered to "alice@example.com"
    And the email should have from address "admin@example.com"

  Scenario: Send emails uses default from address when user has no email
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And the campaign user has no email
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And an email should be delivered to "alice@example.com"
    And the email should have from address matching default

  Scenario: Cannot send emails for another user's campaign
    Given a campaign titled "My Campaign" exists for me
    And there is another user with a separate campaign
    When I send a POST request to "/api/v1/campaigns/#{@other_campaign.id}/send_emails"
    Then the response status should be 404

  Scenario: Send emails with recipient name in subject
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And an email should be delivered to "alice@example.com"
    And the email should have subject containing "Alice"

  Scenario: Send emails with subject fallback when no recipient name
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has name " "
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And an email should be delivered to "alice@example.com"
    And the email should have subject containing "Outreach Update"

