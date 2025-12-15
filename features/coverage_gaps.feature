Feature: Coverage Gaps
  As a developer
  I want to ensure 100% code coverage
  So that all code paths are tested

  Background:
    Given I am logged in
    And I have API keys configured

  # AgentConfig model coverage
  Scenario: AgentConfig validation rejects non-Hash settings
    Given a campaign titled "Test Campaign" exists for me
    When I create an agent config with invalid settings
    Then the agent config should have validation errors

  Scenario: AgentConfig enabled and disabled methods
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config
    When I check if the agent config is enabled
    Then it should be enabled
    When I disable the agent config
    Then it should be disabled

  Scenario: AgentConfig get_setting and set_setting methods
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config with settings:
      """
      {"tone": "formal"}
      """
    When I get the setting "tone" from the agent config
    Then it should equal "formal"
    When I set the setting "persona" to "founder" on the agent config
    Then the agent config should have setting "persona" equal to "founder"

  # Campaign model coverage
  Scenario: Campaign default shared_settings
    Given a campaign titled "Test Campaign" exists for me
    When I check the campaign's shared_settings
    Then it should have default brand_voice
    And it should have default primary_goal

  Scenario: Campaign brand_voice and primary_goal fallbacks
    Given a campaign titled "Test Campaign" exists for me
    When I clear the campaign's shared_settings
    And I check the campaign's brand_voice
    Then it should return default brand_voice
    When I check the campaign's primary_goal
    Then the primary goal should return "book_call"

  # Lead model coverage
  Scenario: Lead serialization returns camelCase
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I serialize the lead
    Then the serialized lead should include "campaignId"
    And the serialized lead should not include "campaign_id"
    And the serialized campaignId should equal the campaign id

  # MarkdownHelper coverage
  Scenario: MarkdownHelper handles blockquotes with accumulated paragraphs
    When I convert markdown with blockquote after paragraph:
      """
      First paragraph line one
      line two

      > Quote line
      """
    Then the HTML should contain blockquote

  Scenario: MarkdownHelper handles bullet lists with accumulated paragraphs
    When I convert markdown with list after paragraph:
      """
      First paragraph line one
      line two

      - Item one
      - Item two
      """
    Then the HTML should contain list items

  Scenario: MarkdownHelper closes list on non-list line
    When I convert markdown with list then paragraph:
      """
      - Item one
      - Item two

      Normal paragraph
      """
    Then the HTML should close the list before paragraph

  Scenario: MarkdownHelper handles blockquote without blank line
    When I convert markdown with blockquote after paragraph:
      """
      First paragraph line one
      > Quote line
      """
    Then the HTML should contain blockquote

  Scenario: MarkdownHelper handles list without blank line
    When I convert markdown with list after paragraph:
      """
      First paragraph line one
      - Item one
      """
    Then the HTML should contain list items

  # Coverage harness exercises
  Scenario: Coverage harness exercises models and helpers
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the model and helper coverage harness
    Then the coverage harness should complete

  Scenario: Coverage harness exercises service and job errors
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the service error coverage harness
    Then the coverage harness should complete

  Scenario: Coverage harness exercises controller helpers
    When I run the controller helper coverage harness
    Then the coverage harness should complete

  Scenario: Service harness covers AI agent logic
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the agent service coverage harness
    Then the coverage harness should complete

  Scenario: Service harness covers Gmail OAuth and email sender
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the Gmail OAuth coverage harness
    And I run the email sender coverage harness
    And I manually exercise the email sender Gmail coverage flows
    And I exercise the EmailSenderService send_email workflows
    Then the coverage harness should complete

  Scenario: LeadAgentService branch coverage harness
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the lead agent service branch coverage harness
    And I run the StageManager coverage harness
    Then the coverage harness should complete

  Scenario: SettingsHelper module coverage harness
    When I run the settings helper coverage harness
    Then the coverage harness should complete

  Scenario: AgentConfigsController internal coverage harness
    Given a campaign titled "Test Campaign" exists for me
    When I run the agent configs controller coverage harness
    Then the coverage harness should complete

  Scenario: LeadsController internal coverage harness
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I run the leads controller coverage harness
    Then the coverage harness should complete


  Scenario: StageManager requests critique when a rewrite has not been critiqued yet
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead stage is "rewritten (1)"
    And the lead has a completed "WRITER" output recorded at "2024-01-01 10:00:00 UTC"
    When I determine the StageManager actions for the lead
    Then the available actions should exactly be "CRITIQUE"

  Scenario: StageManager routes failed rewrites back to WRITER
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead stage is "rewritten (2)"
    And the lead has a completed "WRITER" output recorded at "2024-01-01 10:00:00 UTC"
    And the lead has a critique output recorded at "2024-01-01 12:00:00 UTC" with meets_min "false"
    When I determine the StageManager actions for the lead
    Then the available actions should exactly be "WRITER"

  Scenario: StageManager advances rewrites to DESIGN when critique passes
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead stage is "rewritten (2)"
    And the lead has a completed "WRITER" output recorded at "2024-01-01 10:00:00 UTC"
    And the lead has a critique output recorded at "2024-01-01 12:00:00 UTC" with meets_min "true"
    When I determine the StageManager actions for the lead
    Then the available actions should exactly be "DESIGN"

  # CustomFailureApp coverage
  Scenario: CustomFailureApp production mode signup redirect
    Given authentication is enabled
    And I am in production mode
    When I access a protected resource without authentication
    And the failure app request path is "/signup"
    Then the failure app should redirect to "/signup"

  Scenario: CustomFailureApp production mode non-user scope
    Given authentication is enabled
    And I am in production mode
    When I access a protected resource with non-user scope
    Then the failure app should use default behavior

  # ApplicationController coverage
  Scenario: ApplicationController production path helpers
    Given I am in production mode
    When I call new_user_session_path
    Then the session path should return "/login"
    When I call new_user_registration_path
    Then the registration path should return "/signup"

  Scenario: ApplicationController development path helpers
    Given I am in development mode
    When I call new_user_session_path
    Then it should return Devise default path
    When I call new_user_registration_path
    Then it should return Devise default path

  # BaseController coverage
  Scenario: BaseController development skip_auth default
    Given DISABLE_AUTH is not set
    And I am in development mode
    When I check skip_auth
    Then it should be true

  Scenario: BaseController respects DISABLE_AUTH false flag
    Given DISABLE_AUTH is set to "false"
    And I am in development mode
    When I check skip_auth
    Then it should be false

  Scenario: BaseController handles MissingWarden exception
    Given authentication is enabled
    When I make an API request that raises MissingWarden
    Then the request should handle the exception gracefully

  # AgentConfigsController error paths
  Scenario: AgentConfigsController index with non-existent campaign
    When I send a GET request to "/api/v1/campaigns/9999/agent_configs"
    Then the response status should be 404

  Scenario: AgentConfigsController show with non-existent config
    Given a campaign titled "Test Campaign" exists for me
    When I send a GET request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/9999"
    Then the response status should be 404

  Scenario: AgentConfigsController create with non-existent campaign
    When I send a POST request to "/api/v1/campaigns/9999/agent_configs" with JSON:
      """
      {"agent_config": {"agent_name": "WRITER", "enabled": true}}
      """
    Then the response status should be 404

  Scenario: AgentConfigsController update with fallback params
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config
    When I send a PATCH request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}" with JSON:
      """
      {"enabled": false}
      """
    Then the response status should be 200
    And the agent config should be disabled

  Scenario: AgentConfigsController destroy with non-existent config
    Given a campaign titled "Test Campaign" exists for me
    When I send a DELETE request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/9999"
    Then the response status should be 404

  Scenario: AgentConfigsController index returns configs
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config with settings:
      """
      {"tone": "friendly"}
      """
    When I send a GET request to "/api/v1/campaigns/#{@campaign.id}/agent_configs"
    Then the response status should be 200
    And the JSON response should include "campaignId"

  Scenario: AgentConfigsController show returns config
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config
    When I send a GET request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}"
    Then the response status should be 200
    And the JSON response should include "agentName" with "WRITER"

  Scenario: AgentConfigsController create succeeds
    Given a campaign titled "Test Campaign" exists for me
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agentName": "CRITIQUE", "enabled": true, "settings": {"strictness": "strict"}}}
      """
    Then the response status should be 201
    And the JSON response should include "agentName" with "CRITIQUE"

  Scenario: AgentConfigsController create updates existing config
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/agent_configs" with JSON:
      """
      {"agent_config": {"agentName": "WRITER", "enabled": false, "settings": {"tone": "casual"}}}
      """
    Then the response status should be 200
    And the JSON response should include "agentName" with "WRITER"

  Scenario: AgentConfigsController destroy removes config
    Given a campaign titled "Test Campaign" exists for me
    And the campaign has a "WRITER" agent config
    When I send a DELETE request to "/api/v1/campaigns/#{@campaign.id}/agent_configs/#{@agent_config.id}"
    Then the response status should be 204

  # LeadsController error paths
  Scenario: LeadsController update with non-existent lead
    When I send a PATCH request to "/api/v1/leads/9999" with JSON:
      """
      {"name": "Updated Lead"}
      """
    Then the response status should be 422

  Scenario: LeadsController run_agents async with enqueue error
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And job enqueueing will fail
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    Then the response status should be 500

  Scenario: LeadsController run_agents sync with service error
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead agent service will fail
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=false"
    Then the response status should be 422

  Scenario: LeadsController run_agents sync with unexpected error
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead agent service will raise unexpected error
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=false"
    Then the response status should be 500

  Scenario: LeadsController send_email with service error
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And email delivery will fail
    When I send a POST request to "/api/v1/leads/#{@lead.id}/send_email"
    Then the response status should be 500

  Scenario: LeadsController update_agent_output with missing agent name
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {}
      """
    Then the response status should be 422

  Scenario: LeadsController update_agent_output with invalid agent name
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "INVALID"}
      """
    Then the response status should be 422

  Scenario: LeadsController update_agent_output SEARCH without updatedData
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And a "SEARCH" agent output exists for the lead
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}/update_agent_output" with JSON:
      """
      {"agentName": "SEARCH"}
      """
    Then the response status should be 422

  Scenario: LeadsController update succeeds
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I send a PATCH request to "/api/v1/leads/#{@lead.id}" with JSON:
      """
      {"lead": {"campaignId": "#{@campaign.id}", "name": "Updated Lead", "email": "updated@example.com", "title": "CEO", "company": "Acme"}}
      """
    Then the response status should be 200

  Scenario: LeadsController destroy succeeds
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I send a DELETE request to "/api/v1/leads/#{@lead.id}"
    Then the response status should be 204

  Scenario: LeadsController agent_outputs returns outputs
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And a "WRITER" agent output exists for the lead
    When I send a GET request to "/api/v1/leads/#{@lead.id}/agent_outputs"
    Then the response status should be 200
    And the JSON response should include "outputs"

  Scenario: LeadsController run_agents async success
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And job enqueueing will succeed with job id "123"
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=true"
    Then the response status should be 202
    And the JSON response should include "status" with "queued"

  Scenario: LeadsController run_agents sync success
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead agent service will succeed
    When I send a POST request to "/api/v1/leads/#{@lead.id}/run_agents?async=false"
    Then the response status should be 200
    And the JSON response should include "status" with "completed"

  Scenario: LeadsController send_email succeeds
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And email delivery will succeed
    When I send a POST request to "/api/v1/leads/#{@lead.id}/send_email"
    Then the response status should be 200

  # CampaignsController coverage
  Scenario: CampaignsController show with non-existent campaign
    When I request the page "/campaigns/9999"
    Then the response status should be 404

  Scenario: CampaignsController creates admin user when needed
    Given no users exist
    And DISABLE_AUTH is set to "true"
    When I visit "/campaigns"
    Then an admin user should be created

  Scenario: CampaignsController show renders campaign page
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I visit "/campaigns/#{@campaign.id}"
    Then the response status should be 200

  Scenario: CampaignsController updates admin fallback user fields
    Given a campaign titled "Test Campaign" exists for me
    And the admin user is missing profile metadata
    And DISABLE_AUTH is set to "true"
    When I visit "/campaigns"
    Then the admin user profile should be completed

  # Users::RegistrationsController coverage
  Scenario: User registration with inactive account
    Given authentication is enabled
    And no users exist
    When I register with valid credentials but account is inactive
    Then I should see inactive account message
    And I should be redirected appropriately

  # Users::SessionsController coverage
  Scenario: User login clears remember_me when not checked
    Given a user exists with email "user@example.com"
    And the user has remember_me enabled
    When I log in without remember_me
    Then the user's remember_me should be cleared

  Scenario: User sign out clears remember_me
    Given I am logged in
    And I have remember_me enabled
    When I sign out
    Then the user's remember_me should be cleared

  # Api::V1::CampaignsController error paths
  Scenario: Api::V1::CampaignsController send_emails with non-existent campaign
    When I send a POST request to "/api/v1/campaigns/9999/send_emails"
    Then the response status should be 404

  Scenario: Api::V1::CampaignsController send_emails with service error
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And email delivery will fail
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 500

  Scenario: Api::V1::CampaignsController send_emails succeeds
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "designed"
    And the lead has a "DESIGN" agent output with email content
    And email delivery will succeed
    When I send a POST request to "/api/v1/campaigns/#{@campaign.id}/send_emails"
    Then the response status should be 200

  Scenario: Api::V1::CampaignsController campaign params fallback without campaign
    Given a campaign titled "Test Campaign" exists for me
    When I exercise campaign params without an existing campaign
    Then the coverage harness should complete

  # Api::V1::ApiKeysController error paths
  Scenario: Api::V1::ApiKeysController show without user
    Given authentication is enabled
    And DISABLE_AUTH is set to "false"
    And I am not logged in
    When I send a GET request to "/api/v1/api_keys"
    Then the response status should be 401

  Scenario: Api::V1::ApiKeysController update with validation errors
    Given I am logged in
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": null}
      """
    Then the response status should be 200

  Scenario: Api::V1::ApiKeysController update handles failures
    Given I am logged in
    And API key updates will fail
    When I send a PATCH request to "/api/v1/api_keys" with JSON:
      """
      {"llmApiKey": "value"}
      """
    Then the response status should be 422

  # Additional service coverage scenarios
  Scenario: WriterAgent handles missing candidate in response
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "searched"
    And the lead has a "SEARCH" agent output
    And the campaign has a "WRITER" agent config
    And the writer agent will return empty response
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output
    And the WRITER output should include error information

  Scenario: WriterAgent handles different prompt building branches
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "searched"
    And the lead has a "SEARCH" agent output
    And the campaign has a "WRITER" agent config with settings:
      """
      {"personalization_level": "low", "tone": "formal", "email_length": "very_short", "primary_cta_type": "get_reply", "cta_softness": "soft"}
      """
    When I run the "WRITER" agent on the lead
    Then the lead should have a "WRITER" agent output

  Scenario: CritiqueAgent handles network errors
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    And the lead has a "WRITER" agent output
    And the campaign has a "CRITIQUE" agent config
    And the critique agent will fail with network error
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output

  Scenario: CritiqueAgent handles variant selection
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "written"
    And the lead has a "WRITER" agent output with variants
    And the campaign has a "CRITIQUE" agent config with settings:
      """
      {"variant_selection": "highest_personalization_score"}
      """
    When I run the "CRITIQUE" agent on the lead
    Then the lead should have a "CRITIQUE" agent output

  Scenario: DesignAgent handles empty response
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has stage "critiqued"
    And the lead has a "WRITER" agent output
    And the campaign has a "DESIGN" agent config
    And the design agent will return empty response
    When I run the "DESIGN" agent on the lead
    Then the lead should have a "DESIGN" agent output

  Scenario: LeadAgentService extract_domain from email
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    When I extract the domain from the lead
    Then it should use the email domain

  Scenario: LeadAgentService extract_domain fallback to company
    Given a campaign titled "Test Campaign" exists for me
    And a lead exists for my campaign
    And the lead has no email
    When I extract the domain from the lead
    Then it should use the company name
