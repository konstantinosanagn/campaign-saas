Feature: User Registration
  As a new user
  I want to register for an account
  So that I can use the application

  Background:
    Given authentication is enabled
    And no users exist

  Scenario: User can register with valid credentials
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123", "name": "New User"}}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And a user should exist with email "newuser@example.com"
    And the user should have name "New User"

  Scenario: User can register with first_name and last_name
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123"}, "first_name": "New", "last_name": "User", "workspace_name": "My Workspace", "job_title": "Developer"}
      """
    Then the response status should be 302
    And I should be redirected to the home page
    And a user should exist with email "newuser@example.com"
    And the user should have name "New User"
    And the user should have first_name "New"
    And the user should have last_name "User"
    And the user should have workspace_name "My Workspace"
    And the user should have job_title "Developer"

  Scenario: User registration fails with invalid email
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "invalid-email", "password": "password123", "password_confirmation": "password123"}}
      """
    Then the response status should be 422
    And I should not be logged in
    And no user should exist with email "invalid-email"

  Scenario: User registration fails with mismatched passwords
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "different"}}
      """
    Then the response status should be 422
    And I should not be logged in
    And no user should exist with email "newuser@example.com"

  Scenario: User registration fails with existing email
    Given a user exists with email "existing@example.com"
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "existing@example.com", "password": "password123", "password_confirmation": "password123"}}
      """
    Then the response status should be 422
    And I should not be logged in
    And only one user should exist with email "existing@example.com"

  Scenario: Authenticated user with remember_me cannot access signup page
    Given I am logged in
    And I have remember_me enabled
    When I send a GET request to "/signup"
    Then the response status should be 302
    And I should be redirected to the home page

  Scenario: Authenticated user without remember_me is signed out when accessing signup
    Given I am logged in
    And I do not have remember_me enabled
    When I send a GET request to "/signup"
    Then the response status should be 302
    # After signing out, user is redirected (controller redirects to /signup, but Devise may redirect to root)
    # The important thing is that the user is signed out
    And I should not be logged in
    And the user's remember_created_at should be nil

  Scenario: User registration combines first_name and last_name into name
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123"}, "first_name": "John", "last_name": "Doe"}
      """
    Then the response status should be 302
    And a user should exist with email "newuser@example.com"
    And the user should have name "John Doe"
    And the user should have first_name "John"
    And the user should have last_name "Doe"

  Scenario: User registration with only first_name does not set name
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123"}, "first_name": "John"}
      """
    Then the response status should be 302
    And a user should exist with email "newuser@example.com"
    And the user should have first_name "John"
    And the user name should not be automatically set from first_name

  Scenario: User registration with only last_name does not set name
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123"}, "last_name": "Doe"}
      """
    Then the response status should be 302
    And a user should exist with email "newuser@example.com"
    And the user should have last_name "Doe"
    And the user name should not be automatically set from last_name

  Scenario: User can access signup page
    When I send a GET request to "/signup"
    Then the response status should be 200
    And the response should contain the registration form

  Scenario: User registration handles inactive account flow
    When I send a POST request to "/signup" with params:
      """
      {"user": {"email": "newuser@example.com", "password": "password123", "password_confirmation": "password123"}}
      """
    Then the response status should be 302
    And a user should exist with email "newuser@example.com"

