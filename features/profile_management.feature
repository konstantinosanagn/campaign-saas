Feature: Profile management
  As an authenticated user
  I want to edit my profile
  So that my workspace name and job title are up to date

  Background:
    Given I am logged in as a user

  Scenario: Viewing the profile edit page
    When I visit the profile edit page
    Then I should see the profile completion form

  Scenario: Successfully updating profile
    When I send a PATCH request to "/complete-profile" with JSON:
      """
      {"user": {"workspace_name": "New Workspace", "job_title": "CEO"}}
      """
    Then the response status should be 302
    And the user should have workspace_name "New Workspace"
    And the user should have job_title "CEO"

  Scenario: Updating profile with empty values
    When I send a PATCH request to "/complete-profile" with JSON:
      """
      {"user": {"workspace_name": "", "job_title": ""}}
      """
    Then the response status should be 302
    And the user should have workspace_name ""
    And the user should have job_title ""
