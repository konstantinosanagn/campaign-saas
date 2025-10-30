Feature: Lead input validation
  As a campaign owner
  I want helpful errors when I submit invalid lead data
  So that I can correct entries

  Scenario: Missing email yields validation error
    Given a campaign titled "Data Quality" exists for me
    When I send a POST request to "/api/v1/leads" with JSON:
      """
      {"lead": {"campaignId": #{@campaign.id}, "name": "No Email"}}
      """
    Then the response status should be 422


