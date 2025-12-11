Feature: ApplicationHelper
  As a system
  I want to ensure the helper methods provide correct Gmail status and configuration information
  So that the application can display accurate connection and sender details to users

  Background:
    Given a user exists with email "user@example.com"
    And the environment variable "DEFAULT_GMAIL_SENDER" is set to "user@example.com"

  Scenario: gmail_status_badge returns connected status with email
    Given the user can send gmail
    And the user gmail_email is "user@example.com"
    When I call gmail_status_badge for the user
    Then the application helper result should be "Gmail connected (user@example.com)"

  Scenario: gmail_status_badge returns connected status without email
    Given the user can send gmail
    And the user gmail_email is nil
    When I call gmail_status_badge for the user
    Then the application helper result should be "Gmail connected"

  Scenario: gmail_status_badge returns not connected status
    Given the user cannot send gmail
    When I call gmail_status_badge for the user
    Then the application helper result should be "Gmail not connected"

  Scenario: default_gmail_sender_available? returns true when sender exists and can send gmail
    Given the user can send gmail
    When I call default_gmail_sender_available?
    Then the application helper result should be true

  Scenario: default_gmail_sender_available? returns false when sender does not exist
    Given no user exists with the default sender email
    When I call default_gmail_sender_available?
    Then the application helper result should be false

  Scenario: default_gmail_sender_email returns the default sender email
    When I call default_gmail_sender_email
    Then the application helper result should be "user@example.com"
