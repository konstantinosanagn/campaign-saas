Feature: PWA icon links
  As a user
  I want icons declared for various platforms
  So that the app has proper favicon and touch icons

  Scenario: Icon link tags exist
    Given I am logged in
    When I visit the home page
    Then I should see a link icon of type "image/png"
    And I should see a link icon of type "image/svg+xml"


