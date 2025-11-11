Feature: Update DESIGN agent output via API
  As an authenticated user
  I want to edit the formatted email content
  So that I can refine the design formatting

  Background:
    Given I am logged in

  Scenario: Update DESIGN formatted email content
    Given a lead exists for my campaign
    And a "DESIGN" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "DESIGN", "content": "Subject: Updated\n\n**Updated** email content"}
      """
    Then the response status should be 200
    And the JSON nested value at "outputData.formatted_email" should equal "Subject: Updated\n\n**Updated** email content"
    And the JSON nested value at "outputData.email" should equal "Subject: Updated\n\n**Updated** email content"

  Scenario: Update DESIGN with formatted_email parameter
    Given a lead exists for my campaign
    And a "DESIGN" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "DESIGN", "formatted_email": "Subject: Test\n\n**Bold** text"}
      """
    Then the response status should be 200
    And the JSON nested value at "outputData.formatted_email" should equal "Subject: Test\n\n**Bold** text"

  Scenario: Update DESIGN requires content parameter
    Given a lead exists for my campaign
    And a "DESIGN" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "DESIGN"}
      """
    Then the response status should be 422
    And the JSON response should include "errors"

  Scenario: Cannot update DESIGN output for another user's lead
    Given a campaign titled "My Campaign" exists for me
    And a lead exists for my campaign
    And a "DESIGN" agent output exists for the lead
    And there is another user with a separate campaign
    And the other user has a lead
    # Store the original lead ID before switching users
    And the original lead ID is stored
    # Try to update the other user's lead (which we don't own)
    # Use @other_lead which belongs to @other_campaign (other_user's campaign)
    When I send a PATCH request to "/api/v1/leads/#{@other_lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "DESIGN", "content": "Hacked content"}
      """
    Then the response status should be 404
    # The lead belongs to other_user's campaign, but current_user is admin
    # In test mode with DISABLE_AUTH=true, current_user is always admin
    # So the controller will check: campaigns: { user_id: admin.id }
    # Since @other_lead belongs to @other_campaign (other_user's), it won't be found
    # and will return 404, which is the expected behavior

