Feature: UI Interactions
  As a user
  I want to interact with the web interface
  So that I can manage campaigns and leads visually

  Background:
    Given I am logged in

  Scenario: Dashboard renders React components
    When I visit the home page
    Then I should see the dashboard container
    And the dashboard should mount React components

  Scenario: Dashboard shows empty state when no campaigns exist
    Given I have no campaigns
    When I visit the home page
    Then I should see the empty state message

  Scenario: Dashboard shows campaigns list
    Given a campaign titled "Visible Campaign" exists for me
    When I visit the home page
    Then I should see the campaign in the list

  Scenario: Page has correct title and meta tags
    When I visit the home page
    Then the page title should include "CampAIgn"
    And I should see a meta tag "viewport"
    And I should see a meta tag "description"

  Scenario: Page includes required assets
    When I visit the home page
    Then I should see the stylesheet pack tag
    And I should see the javascript pack tag

  Scenario: Page includes PWA icons
    When I visit the home page
    Then I should see a link icon of type "image/png"
    And I should see a link icon of type "image/svg+xml"

  Scenario: Dashboard root has correct CSS classes
    When I visit the home page
    Then the dashboard root should have CSS class "min-h-screen"

