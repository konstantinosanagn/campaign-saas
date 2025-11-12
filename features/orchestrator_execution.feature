Feature: Orchestrator Execution
  As a system
  I want to execute the full agent pipeline via Orchestrator
  So that I can generate complete emails for companies

  Background:
    Given I am logged in
    And I have API keys configured

  Scenario: Orchestrator.run executes full pipeline (Search → Writer → Critique)
    Given the Orchestrator is configured
    When I run the Orchestrator with company name "Microsoft"
    Then the Orchestrator result should include email content
    And the Orchestrator result should include sources
    And the Orchestrator result should include critique

  Scenario: Orchestrator handles company name input
    Given the Orchestrator is configured
    When I run the Orchestrator with company name "Acme Corp"
    Then the Orchestrator result should include company "Acme Corp"

  Scenario: Orchestrator handles optional recipient parameter
    Given the Orchestrator is configured
    When I run the Orchestrator with company name "Microsoft" and recipient "John Doe"
    Then the Orchestrator result should include recipient "John Doe"

  Scenario: Orchestrator handles product_info and sender_company parameters
    Given the Orchestrator is configured
    When I run the Orchestrator with company name "Microsoft", product_info "SaaS Platform", and sender_company "MyCompany"
    Then the Orchestrator result should include product_info "SaaS Platform"
    And the Orchestrator result should include sender_company "MyCompany"

  Scenario: Orchestrator returns complete email with critique and sources
    Given the Orchestrator is configured
    When I run the Orchestrator with company name "Microsoft"
    Then the Orchestrator result should include email content
    And the Orchestrator result should include sources
    And the Orchestrator result should include critique

  Scenario: Orchestrator raises error when SEARCH agent fails
    Given the Orchestrator is configured
    And the SEARCH agent will fail
    When I run the Orchestrator with company name "Microsoft"
    Then an error should be raised

  Scenario: Orchestrator stops when critique is "None"
    Given the Orchestrator is configured
    And the CRITIQUE agent will return no critique
    When I run the Orchestrator with company name "Microsoft"
    Then the Orchestrator should complete successfully
    And the Orchestrator result should have no critique

  Scenario: Orchestrator completes even when critique is provided
    Given the Orchestrator is configured
    And the CRITIQUE agent will return critique
    When I run the Orchestrator with company name "Microsoft"
    Then the Orchestrator should complete successfully
    And the Orchestrator result should include critique text

