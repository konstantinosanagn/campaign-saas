Feature: User model
  As a system
  I want to ensure the User model methods work as expected
  So that authentication, Gmail, and profile features function correctly

  Background:
    Given a user exists with email "user@example.com" and password "password123"

  Scenario: from_google_omniauth creates or finds user by provider and uid
    Given Google OAuth data with provider "google_oauth2", uid "12345", email "user@example.com", first_name "Test", last_name "User"
    When I call User.from_google_omniauth with the OAuth data
    Then the user should be found or created with email "user@example.com" and provider "google_oauth2"

  Scenario: profile_complete? returns true when workspace_name and job_title are present
    Given the user has workspace_name "Acme" and job_title "Engineer"
    When I check if the user's profile is complete
    Then the result should be true

  Scenario: profile_complete? returns false when workspace_name or job_title is missing
    Given the user has workspace_name nil and job_title "Engineer"
    When I check if the user's profile is complete
    Then the result should be false

  Scenario: gmail_connected? returns true when gmail_refresh_token is present
    Given the user has gmail_refresh_token "token123"
    When I check if the user is gmail connected
    Then the result should be true

  Scenario: gmail_connected? returns false when gmail_refresh_token is missing
    Given the user has gmail_refresh_token nil
    When I check if the user is gmail connected
    Then the result should be false

  Scenario: gmail_token_expired? returns true when token is expired
    Given the user has gmail_token_expires_at in the past
    When I check if the user's gmail token is expired
    Then the result should be true

  Scenario: gmail_token_expired? returns false when token is not expired
    Given the user has gmail_token_expires_at in the future
    When I check if the user's gmail token is expired
    Then the result should be false

  Scenario: can_send_gmail? returns true when access token and email are present
    Given the user has gmail_access_token "access123" and gmail_email "user@example.com"
    When I check if the user can send gmail
    Then the result should be true

  Scenario: can_send_gmail? returns false when access token or email is missing
    Given the user has gmail_access_token nil and gmail_email "user@example.com"
    When I check if the user can send gmail
    Then the result should be false

  Scenario: send_gmail! raises error if cannot send gmail
    Given the user has gmail_access_token nil and gmail_email nil
    When I try to send gmail with the user
    Then a user model error should be raised

  Scenario: from_google_omniauth splits full name when first_name and last_name are missing
    Given Google OAuth data with provider "google_oauth2", uid "99999", email "splitname@example.com", first_name "", last_name ""
    And the OAuth data has name "Test User"
    When I call User.from_google_omniauth with the OAuth data
    Then the user should be found or created with email "splitname@example.com" and provider "google_oauth2"
    And the user's first_name should be "Test"
    And the user's last_name should be "User"
  
  Scenario: from_google_omniauth returns existing user by provider and uid
    Given a user exists with email "existing@example.com" and password "password123"
    And the user has provider "google_oauth2" and uid "abc123"
    Given Google OAuth data with provider "google_oauth2", uid "abc123", email "existing@example.com", first_name "Existing", last_name "User"
    When I call User.from_google_omniauth with the OAuth data
    Then the user should be found or created with email "existing@example.com" and provider "google_oauth2"

  Scenario: send_gmail! calls GmailSender.send_email with correct arguments
    Given the user has gmail_access_token "token123" and gmail_email "user@example.com"
    And I mock GmailSender.send_email
    When I call send_gmail! with to "to@example.com", subject "Hello", text_body "Hi", and html_body "<b>Hi</b>"
    Then GmailSender.send_email should have been called with the user and correct arguments

  Scenario: serialize_from_session calls super with first two arguments
    When I call User.serialize_from_session with three arguments "foo", "bar", "baz"
    Then super should be called with the first two arguments "foo" and "bar"