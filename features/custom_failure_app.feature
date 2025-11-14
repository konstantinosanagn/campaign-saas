Feature: CustomFailureApp
  As a user
  I want authentication failures to redirect correctly
  So that I can access the correct pages

  Background:
    Given authentication is enabled

  Scenario: CustomFailureApp redirects to login in production when accessing protected page
    Given the application is in production mode
    And I am not logged in
    When I request the page "/campaigns"
    Then I should be redirected to "/login"

  Scenario: CustomFailureApp redirects to signup in production when accessing signup path
    Given the application is in production mode
    And I am not logged in
    When I visit "/signup"
    Then I should see the registration form
    And I should not be redirected

  Scenario: CustomFailureApp uses default Devise routes in development
    Given the application is in development mode
    And I am not logged in
    When I visit "/campaigns"
    Then I should be redirected to the default Devise sign in page

  Scenario: CustomFailureApp redirects to login for protected API endpoints in production
    Given the application is in production mode
    And I am not logged in
    When I send a GET request to "/api/v1/campaigns"
    Then the response status should be 401

  Scenario: CustomFailureApp handles authentication failure for campaigns page in production
    Given the application is in production mode
    And I am not logged in
    When I request the page "/campaigns"
    Then I should be redirected to "/login"
    When I visit "/campaigns"
    And the current path should be "/login"

