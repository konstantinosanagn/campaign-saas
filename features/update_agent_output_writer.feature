Feature: Update WRITER agent output via API
  As an authenticated user
  I want to edit the generated email content
  So that I can refine outreach

  Scenario: Update WRITER email content
    Given a lead exists for my campaign
    And a "WRITER" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "WRITER", "content": "Hello there!"}
      """
    Then the response status should be 200
    And the JSON nested value at "outputData.email" should equal "Hello there!"


