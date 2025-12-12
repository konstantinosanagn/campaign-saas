Feature: User remembered state
  As a developer
  I want to ensure user_remembered? logic is fully covered
  So that authentication and remember_me work as expected

  Scenario: user is not signed in
    Given a user is not signed in
    When the system checks if the user is remembered
    Then the remembered user result should be false

  Scenario: user is signed in but has no remember cookie
    Given a user is signed in
    And the user does not have a remember_user_token cookie
    And the user has remember_created_at set in the database
    When the system checks if the user is remembered
    Then the remembered user result should be false

  Scenario: user is signed in with remember cookie but no remember_created_at
    Given a user is signed in
    And the user has a remember_user_token cookie
    And the user does not have remember_created_at set in the database
    When the system checks if the user is remembered
    Then the remembered user result should be false

  Scenario: user is signed in with remember cookie and remember_created_at
    Given a user is signed in
    And the user has a remember_user_token cookie
    And the user has remember_created_at set in the database
    When the system checks if the user is remembered
    Then the remembered user result should be true
