Feature: BaseSerializer
  As a developer
  I want to serialize objects and collections to camelCase JSON using BaseSerializer
  So that the frontend receives the expected format

  Scenario: Serialize a single object with snake_case keys
    Given a Ruby object with snake_case keys
    When I serialize the object with BaseSerializer
    Then the result should be a hash with camelCase keys

  Scenario: Serialize a collection of objects
    Given a collection of Ruby objects with snake_case keys
    When I serialize the collection with BaseSerializer
    Then the result should be an array of hashes with camelCase keys

  Scenario: Serialize nested hashes and arrays
    Given a Ruby object with nested hashes and arrays with snake_case keys
    When I serialize the object with BaseSerializer
    Then all keys in the result should be camelCase, including nested ones
