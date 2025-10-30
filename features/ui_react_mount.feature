Feature: React dashboard mount point
  As a user
  I want the dashboard mount point present
  So that the React app can render

  Scenario: Mount point has expected CSS class
    Given I am logged in
    When I visit the home page
    Then the dashboard root should have CSS class "min-h-screen"


