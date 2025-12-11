Feature: Writer Agent Gemini API error handling
  As a developer
  I want to ensure that writer agen can use Gemini API to generate personalized marketing emails with robust error handling
  So that user can have a smooth experience geenrating emails

  Scenario: Gemini API returns empty response body
    Given the Gemini API returns an empty response body
    When the writer agent requests an email
    Then an error "Gemini API returned empty response" should be raised

  Scenario: Gemini API returns invalid JSON
    Given the Gemini API returns invalid JSON
    When the writer agent requests an email
    Then an error "Failed to parse Gemini API response" should be raised

  Scenario: Gemini API returns a response with an error message "API quota exceeded"
    Given the Gemini API returns a response with an error message "API quota exceeded"
    When the writer agent requests an email
    Then an error "Gemini API error: API quota exceeded" should be raised

  Scenario: Gemini API returns response with invalid structure (no candidates)
    Given the Gemini API returns a response with no candidates
    When the writer agent requests an email
    Then an error "Invalid Gemini response structure" should be raised

  Scenario: Gemini API returns response with candidate but no content parts
    Given the Gemini API returns a response with a candidate but no content parts
    When the writer agent requests an email
    Then an error "Invalid Gemini response structure" should be raised

  Scenario: Gemini API returns response with candidate and content parts but no text
    Given the Gemini API returns a response with a candidate and content parts but no text
    When the writer agent requests an email
    Then the email "Failed to generate email" should be returned

  Scenario: Gemini API returns valid response with email text
    Given the Gemini API returns a valid response with email text "Hello, this is your email!"
    When the writer agent requests an email
    Then the email "Hello, this is your email!" should be returned
