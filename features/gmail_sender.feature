@webmock_enabled
Feature: Gmail Sender
  As a system
  I want satisfy user requests to send emails by sending them via the Gmail API
  So that users can communicate with leads using their Gmail account

  Background:
    Given a user with a valid Gmail access token and Gmail email
    And the user's Gmail token is not expiring soon

  Scenario: Successfully send a plain text email
    Given the Gmail API endpoint will accept the email
    When the Gmail sender sends an email with subject "Hello" and text body "Plain text body"
    Then the email should be sent successfully
    And the Gmail API response should include a message ID

  Scenario: Successfully send an HTML email
    Given the Gmail API endpoint will accept the email
    When the Gmail sender sends an email with subject "Hello HTML" and text body "Plain text" and html body "<p>HTML version</p>"
    Then the email should be sent successfully
    And the Gmail API response should include a message ID

  Scenario: Gmail API returns an authorization error
    Given the Gmail API endpoint returns an authorization error
    When the Gmail sender sends an email with subject "Auth Error" and text body "Body"
    Then a Gmail sender authorization error should be raised

  Scenario: Gmail API returns a non-authorization error
    Given the Gmail API endpoint returns a non-authorization error
    When the Gmail sender sends an email with subject "Other Error" and text body "Body"
    Then a generic Gmail send error should be raised
