Feature: Dashboard empty state
  As a new user
  I want the dashboard to render even without data
  So that I’m guided to create my first campaign

  Scenario: Empty account still shows dashboard
    Given I am logged in
    When I visit the home page
    Then I should see the dashboard container


