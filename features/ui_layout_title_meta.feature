Feature: Layout title and meta tags
  As a user
  I want the page to have correct title and meta tags
  So that the UI renders correctly on devices

  Scenario: Title and viewport are present
    Given I am logged in
    When I visit the home page
    Then the page title should include "CampAIgn"
    And I should see a meta tag "viewport"


