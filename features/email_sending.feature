Feature: Email Sending
  As an authenticated user
  I want to send emails to leads in my campaign
  So that I can reach out to prospects

  Background:
    Given I am logged in

  Scenario: Send emails to ready leads
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "DESIGN" agent output with email content
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "success" with true

  Scenario: Send emails when no ready leads exist
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "queued"
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "sent" with 0

  Scenario: Send emails falls back to WRITER output when DESIGN not available
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "WRITER" agent output with email content
    And the lead does not have a "DESIGN" agent output
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "success" with true

  Scenario: Cannot send emails for another user's campaign
    Given a campaign titled "My Campaign" exists for me
    And there is another user with a separate campaign
    When I send a POST request to "/api/v1/campaigns/#{@other_campaign.id}/send_emails"
    Then the response status should be 404

  Scenario: Send emails returns error count for failed sends
    Given a campaign titled "Email Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "DESIGN" agent output with email content
    And SMTP is not configured
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200
    And the JSON response should include "failed"

