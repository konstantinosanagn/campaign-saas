Feature: Delete a campaign via API
  As an authenticated user
  I want to delete a campaign I own
  So that I can remove unused campaigns

  Scenario: Delete campaign successfully
    Given a campaign titled "To Delete" exists for me
    When I send a DELETE request to "/api/v1/campaigns/#{@campaign.id}"
    Then the response status should be 204


