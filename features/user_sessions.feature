Feature: User Sessions
  As a user
  I want to log in and out
  So that I can access my account

  Background:
    Given authentication is enabled
    Given a user exists with email "user@example.com" and password "password123"

  Scenario: User can log in with valid credentials
    When I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123"}}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should be logged in as "user@example.com"

  Scenario: User can log in with remember_me checked
    When I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123", "remember_me": "1"}}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should be logged in as "user@example.com"
    And the user's remember_created_at should be set

  Scenario: User can log in without remember_me checked
    When I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123", "remember_me": "0"}}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And I should be logged in as "user@example.com"
    And the user's remember_created_at should be nil

  Scenario: User login fails with invalid email
    When I send a POST request to "/login" with params:
      """
      {"user": {"email": "wrong@example.com", "password": "password123"}}
      """
    Then the response status should be 200
    And I should not be logged in

  Scenario: User login fails with invalid password
    When I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "wrongpassword"}}
      """
    Then the response status should be 200
    And I should not be logged in

  Scenario: Authenticated user with remember_me cannot access login page
    Given I am logged in
    And I have remember_me enabled
    When I send a GET request to "/login"
    Then the response status should be 302
    And I should be redirected to the home page

  Scenario: Authenticated user without remember_me is signed out when accessing login
    Given I am logged in
    And I do not have remember_me enabled
    When I send a GET request to "/login"
    Then the response status should be 302
    And I should be redirected to "/login"
    And I should not be logged in
    And the user's remember_created_at should be nil

  Scenario: User can log out
    Given I am logged in
    And I have remember_me enabled
    When I send a DELETE request to "/logout"
    Then the response status should be 302
    And I should be redirected to "/login"
    And I should not be logged in
    And the user's remember_created_at should be nil

  Scenario: User login clears existing remember_me when not checked
    Given I am logged in
    And I have remember_me enabled
    When I send a DELETE request to "/logout"
    And I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123", "remember_me": "0"}}
      """
    Then the response status should be 302
    And I should be logged in as "user@example.com"
    And the user's remember_created_at should be nil

  Scenario: User login with remember_me clears cookie if previously not remembered
    Given I am logged in
    And I do not have remember_me enabled
    When I send a DELETE request to "/logout"
    And I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123", "remember_me": "1"}}
      """
    Then the response status should be 302
    And I should be logged in as "user@example.com"
    And the user's remember_created_at should be set

  Scenario: User login clears remember_me cookie before login if not checked
    Given I am logged in
    And I have remember_me enabled
    When I send a DELETE request to "/logout"
    And I send a POST request to "/login" with params:
      """
      {"user": {"email": "user@example.com", "password": "password123", "remember_me": "0"}}
      """
    Then the response status should be 302
    And I should be logged in as "user@example.com"
    And the user's remember_created_at should be nil

  Scenario: User can access login page
    When I send a GET request to "/login"
    Then the response status should be 200
    And the response should contain the login form

