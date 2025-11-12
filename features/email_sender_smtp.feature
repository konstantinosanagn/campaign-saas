Feature: Email sender service SMTP configuration including OAuth2 and password-based authentication
  As an authenticated user
  I want to configure SMTP delivery with multiple authentication methods
  So that I can send emails securely using either OAuth2 or password-based authentication

  Background:
    Given a user exists
    And I am logged in

  Scenario: EmailSenderService handles delivery method verification failure
    Given a campaign titled "Delivery Method Check Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And SMTP environment is configured
    And ActionMailer delivery_method will change after mail creation
    When I attempt to send email for my lead
    Then the last email send should have succeeded

  Scenario: configure_delivery_method uses OAuth2 SMTP when access token available
    Given a campaign titled "OAuth SMTP Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService valid_access_token will return nil on first call and token on second
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded

  Scenario: configure_delivery_method uses different oauth_user when send_from_email differs
    Given a campaign titled "Different OAuth User Campaign" exists for me
    And there is another user with a separate campaign
    And I set my send_from_email to "other@example.com"
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for user "other@example.com" as true
    And GmailOauthService valid_access_token will return nil for Gmail API and token for SMTP
    And SMTP environment is configured
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded

  Scenario: build_oauth2_smtp_settings generates correct SMTP configuration
    Given a campaign titled "OAuth Settings Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And I set my send_from_email to "custom@example.com"
    And GmailOauthService will report oauth_configured for current user as true
    And GmailOauthService valid_access_token will return nil for Gmail API and token for SMTP
    And SMTP environment is configured with custom settings
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded

  Scenario: build_password_smtp_settings uses environment variables
    Given a campaign titled "Password SMTP Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "WRITER" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as false
    And SMTP environment is configured with custom authentication
    And CampaignMailer delivery will succeed
    When I attempt to send email for my lead
    Then the last email send should have succeeded

  Scenario: configure_delivery_method logs error when no delivery method available
    Given a campaign titled "No Delivery Method Campaign" exists for me
    And a lead exists for my campaign
    And the lead has a "DESIGN" agent output with email content
    And the lead has stage "designed"
    And GmailOauthService will report oauth_configured for current user as false
    And SMTP password is not configured
    When I attempt to send email for my lead
    Then the last email send should have failed with an error
