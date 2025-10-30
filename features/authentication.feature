Feature: User authentication and dashboard access
  As a registered user
  I want to access my campaign dashboard
  So that I can manage campaigns and leads

  Scenario: Logged-in user sees dashboard
    Given I am logged in
    When I visit the home page
    Then I should see the dashboard container


