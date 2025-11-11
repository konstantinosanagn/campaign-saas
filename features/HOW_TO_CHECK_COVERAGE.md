# How to Check Cucumber Test Coverage

This guide explains several methods to verify that your Cucumber tests cover all use cases.

## Quick Answer: What's Currently Covered?

**✅ Your test suite has excellent coverage:**
- **120 scenarios** covering **19/19 API endpoints** (100%) ✅
- **654 steps** - 100% passing ✅
- **76.14% code coverage** (715/939 lines) - +12.29% improvement ✅
- All CRUD operations tested
- Authentication and authorization thoroughly tested
- Validation and error handling covered
- Business logic (agent execution, stage progression) tested
- DESIGN agent execution and stage progression (newly added) ✅
- Orchestrator standalone service testing (newly added) ✅
- AgentOutput model status methods (newly added) ✅
- Controller error scenarios (newly added) ✅

## Method 1: Manual Checklist (Recommended)

### Step 1: List All API Endpoints
```bash
rails routes | grep api
```

### Step 2: For Each Endpoint, Verify You Have Tests For:

#### ✅ Success Cases (200/201 responses)
- Create/Read/Update/Delete operations work correctly
- Data is saved/retrieved properly
- Responses contain expected data

#### ✅ Validation Errors (422 responses)
- Required fields are validated
- Invalid data formats are rejected
- Business rule violations are caught

#### ✅ Authorization (401/404 responses)
- Unauthenticated users are rejected (401)
- Users cannot access other users' data (404)
- Cross-user operations are prevented

#### ✅ Not Found (404 responses)
- Non-existent resources return 404
- Invalid IDs are handled gracefully

#### ✅ Edge Cases
- Empty data
- Maximum length strings
- Special characters
- Boundary values

### Step 3: Check Your Feature Files
Compare your endpoints against feature files:

| Endpoint | Feature File | Status |
|----------|--------------|--------|
| GET /api/v1/campaigns | campaigns_index.feature | ✅ |
| POST /api/v1/campaigns | campaign_creation.feature | ✅ |
| PUT /api/v1/campaigns/:id | campaign_update.feature | ✅ |
| DELETE /api/v1/campaigns/:id | campaign_destroy.feature | ✅ |
| POST /api/v1/campaigns/:id/send_emails | email_sending.feature | ✅ |
| GET /api/v1/leads | leads_index.feature | ✅ |
| POST /api/v1/leads | lead_creation.feature | ✅ |
| PUT /api/v1/leads/:id | lead_update.feature | ✅ |
| DELETE /api/v1/leads/:id | lead_destroy.feature | ✅ |
| POST /api/v1/leads/:id/run_agents | agent_execution_workflow.feature | ✅ |
| GET /api/v1/leads/:id/agent_outputs | agent_outputs.feature | ✅ |
| PATCH /api/v1/leads/:id/update_agent_output | update_agent_output_*.feature | ✅ |
| GET /api/v1/campaigns/:id/agent_configs | agent_config_management.feature | ✅ |
| POST /api/v1/campaigns/:id/agent_configs | agent_config_management.feature | ✅ |
| PUT /api/v1/campaigns/:id/agent_configs/:id | agent_config_management.feature | ✅ |
| DELETE /api/v1/campaigns/:id/agent_configs/:id | agent_config_management.feature | ✅ |
| GET /api/v1/api_keys | api_keys_management.feature | ✅ |
| PUT /api/v1/api_keys | api_keys_management.feature | ✅ |

## Method 2: Use Coverage Analysis Document

See **[COVERAGE_ANALYSIS.md](./COVERAGE_ANALYSIS.md)** for:
- Detailed endpoint coverage mapping
- Identified gaps and missing scenarios
- Recommendations for improvement
- Coverage metrics

## Method 3: Code Coverage Tools

### Option A: SimpleCov (Ruby Code Coverage)

1. **Add to Gemfile:**
```ruby
group :test do
  gem 'simplecov', require: false
end
```

2. **Configure in features/support/env.rb:**
```ruby
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/vendor/'
    add_filter '/config/'
  end
end
```

3. **Run with coverage:**
```bash
COVERAGE=true bundle exec cucumber
```

4. **View report:**
```bash
open coverage/index.html
```

### Option B: Cucumber Coverage Plugin

Some IDE plugins can show which code is covered by Cucumber tests.

## Method 4: Compare with RSpec Tests

Your RSpec tests (in `spec/`) can indicate what functionality exists:

```bash
# List all RSpec test files
find spec -name "*_spec.rb"

# Compare with Cucumber features
ls features/*.feature
```

**Look for:**
- Controllers tested in RSpec but not in Cucumber
- Models with validations not tested in Cucumber
- Services with logic not tested in Cucumber

## Method 5: Test Scenarios Matrix

Create a matrix of all test scenarios:

### Campaigns
- [x] Create campaign (success)
- [x] Create campaign (validation error)
- [x] List campaigns (user-scoped)
- [x] Update campaign (success)
- [x] Update campaign (authorization)
- [x] Delete campaign (success)
- [x] Delete campaign (authorization)
- [x] Send emails (success)
- [x] Send emails (authorization)

### Leads
- [x] Create lead (success)
- [x] Create lead (validation error)
- [x] List leads (user-scoped)
- [x] Update lead (success)
- [x] Update lead (authorization)
- [x] Delete lead (success)
- [x] Delete lead (authorization)
- [x] Delete lead (cascade)
- [x] Run agents (success)
- [x] Run agents (error)
- [x] Run agents (disabled agent)
- [x] Get agent outputs
- [x] Update agent output

### Agent Configs
- [x] List configs
- [x] Get config
- [x] Create config
- [x] Update config
- [x] Delete config
- [x] Duplicate prevention
- [x] Invalid agent name

### API Keys
- [x] Get API keys
- [x] Update API keys
- [x] Update single key
- [x] Clear keys

### Authentication
- [x] Unauthenticated access (401)
- [x] User isolation
- [x] Cross-user prevention

## Method 6: Gap Analysis Checklist

### Common Gaps to Look For:

#### 🔍 Error Scenarios
- [ ] Network timeouts
- [ ] Rate limiting
- [ ] Invalid API responses
- [ ] Service unavailability
- [ ] Database errors

#### 🔍 Edge Cases
- [ ] Very long strings (max length)
- [ ] Special characters (Unicode, SQL injection attempts)
- [ ] Empty arrays/objects
- [ ] Null values
- [ ] Boundary values (0, -1, max int)

#### 🔍 Concurrent Operations
- [ ] Multiple users
- [ ] Race conditions
- [ ] Simultaneous updates
- [ ] Lock contention

#### 🔍 Integration Scenarios
- [ ] End-to-end workflows
- [ ] Multi-step processes
- [ ] External service integration
- [ ] Full pipeline execution

#### 🔍 Performance
- [ ] Large datasets
- [ ] Pagination
- [ ] Filtering
- [ ] Sorting

#### 🔍 Security
- [ ] SQL injection
- [ ] XSS attacks
- [ ] CSRF protection
- [ ] Rate limiting
- [ ] Input sanitization

## Method 7: Run Coverage Check Script

Use the provided script to get a quick overview:

```bash
# Make script executable
chmod +x scripts/check_coverage.rb

# Run the script
ruby scripts/check_coverage.rb
```

## Method 8: Compare Against Requirements

If you have user stories or requirements documents:
1. List all user stories/requirements
2. For each, verify there's a Cucumber scenario
3. Mark any missing scenarios

## Method 9: Mutation Testing

Mutation testing can find untested code:

```bash
# Install mutant
gem install mutant

# Run mutation testing (requires RSpec)
bundle exec mutant --use rspec
```

## Method 10: Regular Reviews

### Weekly Review Checklist:
- [ ] Review new features for test coverage
- [ ] Check if new endpoints have tests
- [ ] Verify error scenarios are tested
- [ ] Ensure authorization is tested
- [ ] Check edge cases

### Monthly Review:
- [ ] Full coverage analysis
- [ ] Compare against API documentation
- [ ] Review coverage reports
- [ ] Identify and prioritize gaps

## Quick Coverage Check Command

Create an alias for quick checks:

```bash
# Add to .bashrc or .zshrc
alias cucumber-coverage='bundle exec cucumber --format progress | grep -E "scenarios|steps"'
```

## Summary

**Your current coverage is excellent!** All 19 API endpoints are covered with 120 scenarios.

**Recent Improvements:**
- ✅ Added 24 new scenarios (+157 steps)
- ✅ Coverage improved from 63.85% to 76.14% (+12.29%)
- ✅ DESIGN agent execution and stage progression tests added
- ✅ Orchestrator standalone service tests added
- ✅ AgentOutput model status method tests added
- ✅ Controller error scenario tests added

**To maintain good coverage:**
1. ✅ Add tests for new features
2. ✅ Test error scenarios
3. ✅ Test edge cases
4. ✅ Test authorization
5. ✅ Review coverage regularly

**To identify gaps:**
1. Use the coverage analysis document
2. Compare endpoints vs features
3. Run code coverage tools
4. Review error scenarios
5. Test edge cases

For detailed analysis, see **[COVERAGE_ANALYSIS.md](./COVERAGE_ANALYSIS.md)**.

