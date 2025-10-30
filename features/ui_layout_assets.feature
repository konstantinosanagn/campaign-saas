Feature: Layout asset tags
  As a user
  I want CSS and JS pack tags to be present
  So that styles and scripts load

  Scenario: Pack tags are included
    Given I am logged in
    When I visit the home page
    Then I should see the stylesheet pack tag
    And I should see the javascript pack tag


