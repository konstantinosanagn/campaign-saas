Feature: Campaign mailer email formatting

  Background:
    Given a user exists
    And I am logged in

  Scenario: CampaignMailer sends email with custom from and recipient name
    When I deliver a campaign email to "alice@example.com" with recipient_name "Alice" and campaign_title "Acme" and from_email "me@example.com"
    Then an email should be delivered to "alice@example.com"
    And the email should have subject containing "Outreach for Alice"
    And the email should have from address "me@example.com"

  Scenario: CampaignMailer falls back subject when recipient name blank and uses default from
    Given a lead exists for my campaign
    When I deliver a campaign email to "bob@example.com" with recipient_name " " and campaign_title "My Campaign"
    Then an email should be delivered to "bob@example.com"
    And the email should have subject containing "Outreach Update"
    And the email should have from address matching default
