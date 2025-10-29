# Test Suite

This directory contains tests for the WriterAgent.

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with documentation
bundle exec rspec --format documentation

# Run a specific file
bundle exec rspec spec/writer_agent_spec.rb

# Run with coverage (if using simplecov)
COVERAGE=true bundle exec rspec
```

## Test Coverage

The WriterAgent tests cover:

- ✅ API integration with OpenAI
- ✅ Article generation from search results
- ✅ Error handling for API failures
- ✅ Handling of empty/missing sources
- ✅ Prompt construction
- ✅ Data flow through the agent

## Test Structure

All tests use WebMock to mock external API calls, ensuring:
- Tests run offline
- No real API costs
- Predictable test results
- Fast test execution
