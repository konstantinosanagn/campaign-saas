Feature: Batch lead processing service
  As a user
  I want to process multiple leads in batches efficiently
  So that campaigns can scale and errors are handled gracefully

  Background:
    Given a user exists
    And a campaign exists for the user
    And the campaign has leads

  Scenario: Process leads in batches successfully
    When I process all leads in the campaign using the batch lead processing service
    Then all leads should be queued for processing
    And the result should include the correct total and queued count

  Scenario: Some leads fail to queue
    Given some leads will fail to enqueue
    When I process all leads in the campaign using the batch lead processing service
    Then the result should include failed leads
    And the failed count should be correct

  Scenario: No valid leads found
    Given the campaign has no valid leads
    When I process leads using the batch lead processing service
    Then the result should include an error message
    And the completed, failed, and queued lists should be empty

  Scenario: Unauthorized user tries to process leads
    Given a user that does not own the campaign
    When the user tries to process leads using the batch lead processing service
    Then the result should include an error message
    And no leads should be processed

  Scenario: Process leads synchronously in batches successfully
    When I process all leads in the campaign synchronously using the batch lead processing service
    Then all leads should be completed synchronously
    And the sync result should include the correct total and completed count

  Scenario: Unauthorized user tries to process leads synchronously
    Given a user that does not own the campaign
    When the user tries to process leads synchronously using the batch lead processing service
    Then the result should include an error message
    And no leads should be processed synchronously

  Scenario: Batch size is set by ENV
    Given the environment variable BATCH_SIZE is set to 5
    When I get the recommended batch size from the batch lead processing service
    Then the recommended batch size should be 5

  Scenario: Batch size defaults for environment
    Given the environment variable BATCH_SIZE is not set
    And Rails is in production environment
    When I get the recommended batch size from the batch lead processing service
    Then the recommended batch size should be 25

  Scenario: Batch size defaults for development
    Given the environment variable BATCH_SIZE is not set
    And Rails is in development environment
    When I get the recommended batch size from the batch lead processing service
    Then the recommended batch size should be 10
