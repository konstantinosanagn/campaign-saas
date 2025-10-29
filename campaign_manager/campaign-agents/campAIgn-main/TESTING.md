# WriterAgent Testing Guide

## Test Coverage

The test suite for WriterAgent (`spec/writer_agent_spec.rb`) provides comprehensive coverage of the agent's functionality.

### Test Categories

#### 1. Initialization Tests
- Custom API key configuration
- Custom model selection (gpt-4, gpt-3.5-turbo, etc.)
- Default model configuration

#### 2. Core Functionality Tests

**With Successful API Response:**
- ✅ Generates article with proper structure
- ✅ Preserves domain and source information
- ✅ Passes authentication headers
- ✅ Returns expected data structure

**With API Errors:**
- ✅ Handles HTTP 500 errors gracefully
- ✅ Handles network timeouts
- ✅ Handles rate limit errors (HTTP 429)
- ✅ Returns error messages in output

**With Edge Cases:**
- ✅ Handles empty/missing sources
- ✅ Handles malformed API responses
- ✅ Handles JSON parsing errors
- ✅ Generates articles even without detailed sources

#### 3. Private Method Tests (`#build_prompt`)

**Prompt Construction:**
- ✅ Creates comprehensive prompts with all required elements
- ✅ Includes source information (title, URL, content)
- ✅ Includes image references when available
- ✅ Handles multiple sources correctly
- ✅ Includes article structure guidelines (introduction, conclusion, etc.)
- ✅ Handles sources without content gracefully

## Running Tests

### Basic Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run with detailed documentation
bundle exec rspec --format documentation

# Run a specific test file
bundle exec rspec spec/writer_agent_spec.rb

# Run specific test by name
bundle exec rspec spec/writer_agent_spec.rb -e "generates an article"

# Run with progress indicator
bundle exec rspec --format progress

# Run tests and show code coverage (if using simplecov)
COVERAGE=true bundle exec rspec
```

### Test Output

Expected output when running:
```
WriterAgent
  initialization
    accepts custom API key
    accepts custom model
    defaults to gpt-4 model
  #run
    with successful API response
      generates an article
      preserves domain and sources
      includes sources in the prompt
    with API error
      handles errors gracefully
    with no sources
      still generates an article
  private methods
    #build_prompt
      constructs a comprehensive prompt
      includes image reference when provided
      handles multiple sources
      handles sources without content gracefully
  edge cases
    with malformed API response
      handles JSON parsing errors
    with timeout
      handles network timeouts
    with rate limit error
      handles rate limit errors

Finished in X.XX seconds
XX examples, 0 failures
```

## What's Being Tested

### API Integration
- Real API calls are mocked using WebMock
- Tests verify correct headers and body structure
- Tests verify authentication tokens are passed

### Error Handling
- Tests ensure the agent doesn't crash on errors
- Error messages are preserved in the output
- All error scenarios return a valid hash structure

### Data Flow
- Input from SearchAgent → WriterAgent
- WriterAgent output → CritiqueAgent input
- All metadata (domain, sources, image) is preserved

### Prompt Quality
- Sources are properly formatted in prompts
- Instructions for article structure are included
- Image references are included when available

## Test Structure

```ruby
RSpec.describe WriterAgent do
  # Setup (let blocks, mocks, etc.)
  
  describe 'initialization' do
    # Test constructor and configuration
  end
  
  describe '#run' do
    context 'with successful API response' do
      # Test happy path
    end
    
    context 'with API error' do
      # Test error handling
    end
    
    context 'with edge cases' do
      # Test unusual inputs
    end
  end
  
  describe 'private methods' do
    describe '#build_prompt' do
      # Test prompt construction logic
    end
  end
end
```

## Mocking Strategy

All external API calls are mocked to:
- ✅ Run tests offline
- ✅ Avoid API costs during development
- ✅ Provide predictable, consistent results
- ✅ Test various error scenarios
- ✅ Run tests quickly without network latency

```ruby
# Example mock
stub_request(:post, 'https://api.openai.com/v1/chat/completions')
  .with(headers: { 'Authorization' => "Bearer #{api_key}" })
  .to_return(
    status: 200,
    body: { 'choices' => [{ 'message' => { 'content' => 'Article' } }] }.to_json
  )
```

## Best Practices

1. **Isolation**: Each test is independent and doesn't rely on others
2. **Clarity**: Test names describe what they're testing
3. **Coverage**: All public methods and significant edge cases are tested
4. **Speed**: Tests complete in under a second without real API calls
5. **Reliability**: Tests are deterministic and produce consistent results

## Adding New Tests

When adding new functionality to WriterAgent:

1. Add a new test case in the appropriate `describe` or `context` block
2. Mock the API call appropriately
3. Verify both successful and error scenarios
4. Run tests to ensure they pass: `bundle exec rspec`
5. Update this documentation if needed

## Troubleshooting

### Tests failing due to network requests
```bash
# Verify WebMock is blocking external requests
bundle exec rspec --format documentation
```

### Tests timing out
- Check mock setup in `before` blocks
- Verify WebMock is properly configured in `spec_helper.rb`

### Unexpected test failures
- Check if API response format has changed
- Verify mock responses match actual API format
- Check for typos in test expectations

