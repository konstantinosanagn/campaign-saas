# Cucumber Test Coverage Analysis

This document helps identify what's covered by Cucumber tests and what might be missing.

## Current Coverage Summary

### ✅ Fully Covered API Endpoints

#### Campaigns API (`/api/v1/campaigns`)
- ✅ `GET /api/v1/campaigns` - List campaigns
  - Covered in: `campaigns_index.feature`, `authentication_comprehensive.feature`
  - Tests: User can only see their own campaigns, authorization checks
- ✅ `POST /api/v1/campaigns` - Create campaign
  - Covered in: `campaign_creation.feature`, `campaign_validation.feature`, `campaign_validation_comprehensive.feature`
  - Tests: Success case, validation errors (nil title, empty title, long title), shared settings
- ✅ `PUT /api/v1/campaigns/:id` - Update campaign
  - Covered in: `campaign_update.feature`, `campaign_authorization.feature`, `authentication_comprehensive.feature`
  - Tests: Update success, authorization (cannot update another user's campaign), shared settings update
- ✅ `DELETE /api/v1/campaigns/:id` - Delete campaign
  - Covered in: `campaign_destroy.feature`, `campaign_authorization.feature`, `authentication_comprehensive.feature`
  - Tests: Delete success, authorization (cannot delete another user's campaign)
- ✅ `POST /api/v1/campaigns/:id/send_emails` - Send emails
  - Covered in: `email_sending.feature`
  - Tests: Send emails to ready leads, fallback to WRITER output, error handling, authorization

#### Leads API (`/api/v1/leads`)
- ✅ `GET /api/v1/leads` - List leads
  - Covered in: `leads_index.feature`, `authentication_comprehensive.feature`
  - Tests: List all leads, user-scoped access
- ✅ `POST /api/v1/leads` - Create lead
  - Covered in: `lead_creation.feature`, `lead_validation.feature`, `lead_validation_comprehensive.feature`
  - Tests: Success case, validation errors (missing email, name, title, company, invalid email), authorization
- ✅ `PUT /api/v1/leads/:id` - Update lead
  - Covered in: `lead_update.feature`, `authentication_comprehensive.feature`
  - Tests: Update success, authorization
- ✅ `DELETE /api/v1/leads/:id` - Delete lead
  - Covered in: `lead_destroy.feature`, `lead_deletion.feature`, `authentication_comprehensive.feature`
  - Tests: Delete success, authorization, cascade delete (agent outputs), 404 for non-existent
- ✅ `POST /api/v1/leads/:id/run_agents` - Run agents
  - Covered in: `agent_execution_workflow.feature`, `lead_stage_progression.feature`, `run_agents_error.feature`
  - Tests: Run agents successfully, stage progression, disabled agents, API key validation, error handling, already completed leads
- ✅ `GET /api/v1/leads/:id/agent_outputs` - Get agent outputs
  - Covered in: `agent_outputs.feature`, `agent_outputs_comprehensive.feature`, `authentication_comprehensive.feature`
  - Tests: Get all outputs, empty outputs, authorization
- ✅ `PATCH /api/v1/leads/:id/update_agent_output` - Update agent output
  - Covered in: `update_agent_output_writer.feature`, `update_agent_output_search.feature`, `agent_outputs_comprehensive.feature`
  - Tests: Update WRITER output, Update SEARCH output, Update DESIGN output, invalid agent name, authorization

#### Agent Configs API (`/api/v1/campaigns/:campaign_id/agent_configs`)
- ✅ `GET /api/v1/campaigns/:campaign_id/agent_configs` - List agent configs
  - Covered in: `agent_config_management.feature`
  - Tests: List configs, authorization
- ✅ `GET /api/v1/campaigns/:campaign_id/agent_configs/:id` - Get agent config
  - Covered in: `agent_config_management.feature`
  - Tests: Get specific config, authorization
- ✅ `POST /api/v1/campaigns/:campaign_id/agent_configs` - Create agent config
  - Covered in: `agent_config_management.feature`
  - Tests: Create config, duplicate prevention, invalid agent name, authorization
- ✅ `PUT /api/v1/campaigns/:campaign_id/agent_configs/:id` - Update agent config
  - Covered in: `agent_config_management.feature`
  - Tests: Update settings, disable/enable, authorization
- ✅ `DELETE /api/v1/campaigns/:campaign_id/agent_configs/:id` - Delete agent config
  - Covered in: `agent_config_management.feature`
  - Tests: Delete config, authorization

#### API Keys API (`/api/v1/api_keys`)
- ✅ `GET /api/v1/api_keys` - Get API keys
  - Covered in: `api_keys_management.feature`, `api_keys_validation.feature`
  - Tests: Get stored keys, empty keys
- ✅ `PUT /api/v1/api_keys` - Update API keys
  - Covered in: `api_keys_management.feature`, `api_keys_validation.feature`
  - Tests: Update both keys, update single key, clear keys

#### Authentication
- ✅ Unauthenticated access (401 responses)
  - Covered in: `authentication_comprehensive.feature`
  - Tests: Cannot access campaigns, cannot create campaigns, proper 401 responses for JSON API
- ✅ Authorization (user-scoped access)
  - Covered in: `authentication_comprehensive.feature`, `campaign_authorization.feature`
  - Tests: Users can only see their own campaigns, cannot update/delete other users' campaigns, cannot access other users' leads

#### UI Components
- ✅ Dashboard rendering
  - Covered in: `ui_interactions.feature`, `dashboard_empty_state.feature`
  - Tests: React components mount, empty state, campaign list display
- ✅ Layout and assets
  - Covered in: `ui_layout_title_meta.feature`, `ui_layout_assets.feature`, `ui_pwa_icons.feature`, `ui_react_mount.feature`
  - Tests: Title, meta tags, stylesheet pack, javascript pack, PWA icons

### ✅ Business Logic Coverage

#### Agent Execution
- ✅ Stage progression: `queued → searched → written → critiqued → completed`
  - Covered in: `lead_stage_progression.feature`, `agent_execution_workflow.feature`
- ✅ Disabled agent handling
  - Covered in: `agent_execution_workflow.feature`
  - Tests: Skipping disabled agents, advancing past disabled agents
- ✅ Agent failure handling
  - Covered in: `lead_stage_progression.feature`, `agent_execution_workflow.feature`
  - Tests: Stage doesn't progress on failure, error storage
- ✅ Agent output storage and retrieval
  - Covered in: `agent_outputs.feature`, `agent_outputs_comprehensive.feature`
- ✅ Agent output updates
  - Covered in: `update_agent_output_writer.feature`, `update_agent_output_search.feature`, `agent_outputs_comprehensive.feature`

#### Campaign-Lead Relationship
- ✅ Campaign shared settings
  - Covered in: `campaign_shared_settings.feature`, `campaign_leads_relationship.feature`
- ✅ Lead association with campaigns
  - Covered in: `campaign_leads_relationship.feature`

#### Email Sending
- ✅ Send emails to ready leads
  - Covered in: `email_sending.feature`
  - Tests: Send to critiqued leads, fallback to WRITER output, error handling

## Potential Gaps & Missing Coverage

### 🔍 Areas to Review

#### 1. Edge Cases & Error Scenarios
- [ ] **Network/API failures**: Mock external API failures (Tavily, Gemini)
  - Current: Basic error handling exists, but could test more specific failure scenarios
  - Suggestion: Add scenarios for timeout, rate limiting, invalid API keys
  
- [ ] **Concurrent operations**: Multiple users, race conditions
  - Current: Single-user scenarios are covered
  - Suggestion: Test concurrent lead updates, campaign modifications

- [ ] **Large datasets**: Performance with many campaigns/leads
  - Current: Basic CRUD operations tested
  - Suggestion: Test pagination, filtering, sorting if implemented

#### 2. Data Validation Edge Cases
- [ ] **Boundary values**: Maximum length strings, special characters
  - Current: Long title (255 chars) is tested
  - Suggestion: Test Unicode characters, SQL injection attempts, XSS attempts
  
- [ ] **Required fields**: All combinations of missing fields
  - Current: Individual missing fields tested
  - Suggestion: Test multiple missing fields simultaneously

#### 3. Agent-Specific Scenarios
- [ ] **DESIGN agent**: Update DESIGN output is tested, but execution flow could be more comprehensive
  - Current: DESIGN output update is covered
  - Suggestion: Test DESIGN agent execution in full pipeline
  
- [ ] **Agent dependencies**: WRITER needs SEARCH, CRITIQUE needs WRITER
  - Current: Basic dependency handling exists
  - Suggestion: Test missing dependency scenarios (e.g., run WRITER without SEARCH)

#### 4. Integration Scenarios
- [ ] **Full pipeline**: SEARCH → WRITER → DESIGN → CRITIQUE end-to-end
  - Current: Individual agent execution and stage progression tested
  - Suggestion: Test complete pipeline in single scenario
  
- [ ] **Email sending integration**: Full email sending flow with SMTP
  - Current: Basic email sending tested
  - Suggestion: Test actual SMTP delivery, bounce handling

#### 5. UI/UX Scenarios
- [ ] **User interactions**: Form submissions, modal interactions, real user workflows
  - Current: Basic UI rendering tested
  - Suggestion: Test user interactions, form validation, error messages
  
- [ ] **Responsive design**: Mobile/tablet views
  - Current: Not explicitly tested
  - Suggestion: Test responsive layouts if applicable

#### 6. Security Scenarios
- [ ] **CSRF protection**: Verify CSRF tokens are handled
  - Current: API uses `null_session`, CSRF skipped for API
  - Suggestion: Test CSRF protection for web forms if applicable
  
- [ ] **Rate limiting**: Test Rack::Attack rate limits
  - Current: Rate limiting configured but not tested
  - Suggestion: Test rate limiting behavior

#### 7. Data Integrity
- [ ] **Cascade deletes**: Verify all related records are deleted
  - Current: Agent outputs deletion tested
  - Suggestion: Test campaign deletion cascades to leads and agent configs
  
- [ ] **Transaction rollbacks**: Test database transaction handling
  - Current: Not explicitly tested
  - Suggestion: Test rollback scenarios on errors

## How to Identify Coverage Gaps

### Method 1: Code Coverage Analysis
```bash
# Install simplecov for Cucumber
# Add to Gemfile: gem 'simplecov', require: false, group: :test

# Run Cucumber with coverage
COVERAGE=true bundle exec cucumber

# View coverage report
open coverage/index.html
```

### Method 2: Manual Checklist
1. **List all controllers and actions**
   ```bash
   rails routes | grep api
   ```

2. **For each endpoint, verify:**
   - ✅ Success case (200/201)
   - ✅ Validation errors (422)
   - ✅ Authorization (401/404)
   - ✅ Not found (404)
   - ✅ Edge cases

3. **List all models and verify:**
   - ✅ CRUD operations
   - ✅ Validations
   - ✅ Associations
   - ✅ Callbacks

### Method 3: Feature Parity Check
Compare your Cucumber features against:
- API documentation
- User stories/requirements
- RSpec test coverage (check `spec/` directory)
- Application functionality (manual testing)

### Method 4: Mutation Testing
Use tools like `mutant` to find untested code:
```bash
gem install mutant
bundle exec mutant --use rspec
```

## Coverage Metrics

### Current Statistics
- **Total Scenarios**: 96
- **Total Steps**: 497
- **Feature Files**: 38
- **Pass Rate**: 100% ✅

### API Endpoint Coverage
- **Campaigns**: 5/5 endpoints (100%)
- **Leads**: 7/7 endpoints (100%)
- **Agent Configs**: 5/5 endpoints (100%)
- **API Keys**: 2/2 endpoints (100%)
- **Total**: 19/19 endpoints (100%)

### Test Types Coverage
- ✅ **Happy paths**: Covered
- ✅ **Validation errors**: Covered
- ✅ **Authorization**: Covered
- ✅ **Error handling**: Partially covered
- ⚠️ **Edge cases**: Some gaps
- ⚠️ **Integration scenarios**: Some gaps
- ⚠️ **Performance**: Not tested

## Recommendations

### High Priority
1. **Add error scenario tests**: Test more specific error conditions (timeouts, rate limits, invalid responses)
2. **Test agent dependencies**: Verify agents fail gracefully when dependencies are missing
3. **Test concurrent operations**: Multiple users, race conditions
4. **Test data integrity**: Cascade deletes, transaction rollbacks

### Medium Priority
1. **Add performance tests**: Large datasets, pagination
2. **Add security tests**: Rate limiting, CSRF, XSS, SQL injection
3. **Add integration tests**: Full pipeline execution
4. **Add UI interaction tests**: Form submissions, user workflows

### Low Priority
1. **Add accessibility tests**: WCAG compliance
2. **Add responsive design tests**: Mobile/tablet views
3. **Add browser compatibility tests**: Different browsers

## Tools for Coverage Analysis

### 1. SimpleCov (Code Coverage)
```ruby
# Gemfile
group :test do
  gem 'simplecov', require: false
end

# features/support/env.rb
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/features/'
  end
end
```

### 2. Cucumber Formatters
```bash
# JSON formatter for analysis
bundle exec cucumber --format json --out coverage.json

# HTML formatter
bundle exec cucumber --format html --out coverage.html
```

### 3. Custom Coverage Script
Create a script to compare routes vs features:
```ruby
# scripts/coverage_check.rb
require 'rails'
require_relative '../config/routes'

routes = Rails.application.routes.routes
api_routes = routes.select { |r| r.path.spec.to_s.start_with?('/api/v1') }

# Compare against feature files
feature_files = Dir['features/**/*.feature']
# Analysis logic here
```

## Conclusion

Your Cucumber test suite has **excellent coverage** of the core functionality:
- ✅ All API endpoints are tested
- ✅ Authentication and authorization are thoroughly tested
- ✅ Validation and error handling are covered
- ✅ Business logic (agent execution, stage progression) is tested
- ✅ UI components are tested

**Areas for improvement:**
- ⚠️ More edge case scenarios
- ⚠️ Integration/end-to-end scenarios
- ⚠️ Performance and security testing
- ⚠️ Concurrent operation testing

The current test suite provides a **solid foundation** and covers all critical user flows. The suggested improvements would enhance robustness and catch edge cases that might not be apparent in normal usage.

