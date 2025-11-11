# Cucumber Test Suite

This directory contains comprehensive Cucumber feature files covering all functionality of the CampAIgn application.

## Feature Files

### Authentication & Authorization
- **authentication.feature** - Basic authentication and dashboard access
- **authentication_comprehensive.feature** - Comprehensive authentication and authorization scenarios including:
  - Unauthenticated access prevention
  - User data isolation
  - Campaign and lead ownership validation
  - Cross-user access prevention

### Campaign Management
- **campaign_creation.feature** - Create campaigns via API
- **campaign_update.feature** - Update campaign details
- **campaign_destroy.feature** - Delete campaigns
- **campaigns_index.feature** - List user's campaigns
- **campaign_authorization.feature** - Campaign ownership and authorization
- **campaign_validation.feature** - Campaign input validation (basic)
- **campaign_validation_comprehensive.feature** - Comprehensive campaign validation:
  - Missing title validation
  - Empty title validation
  - Long title handling
  - Shared settings validation
- **campaign_shared_settings.feature** - Campaign shared settings management:
  - Create campaign with shared settings
  - Update shared settings
  - Settings usage by agents
- **campaign_leads_relationship.feature** - Campaign-leads relationship management:
  - List leads for campaigns
  - User-scoped lead access
  - Campaign deletion cascades to leads
  - Lead-campaign association persistence

### Lead Management
- **lead_creation.feature** - Create leads via API
- **lead_update.feature** - Update lead details
- **lead_destroy.feature** - Delete leads (basic)
- **lead_deletion.feature** - Comprehensive lead deletion:
  - Delete lead successfully
  - Cross-user deletion prevention
  - Cascading agent output deletion
  - Non-existent lead handling
- **leads_index.feature** - List user's leads
- **lead_validation.feature** - Lead input validation (basic)
- **lead_validation_comprehensive.feature** - Comprehensive lead validation:
  - Missing email validation
  - Missing name validation
  - Missing title validation
  - Missing company validation
  - Invalid email format validation
  - Non-existent campaign validation
  - Cross-user campaign validation

### Agent Management
- **agent_config_management.feature** - Agent configuration CRUD operations:
  - List agent configs
  - Get specific agent config
  - Create agent config
  - Update agent config settings
  - Delete agent config
  - Duplicate config prevention
  - Invalid agent name validation
  - Cross-user access prevention
- **agent_execution_workflow.feature** - Agent execution workflows:
  - Run agents on leads
  - Stage progression
  - API key validation
  - Completed lead handling
  - Disabled agent handling
  - Output storage
  - Error handling
- **agent_outputs.feature** - Basic agent outputs retrieval
- **agent_outputs_comprehensive.feature** - Comprehensive agent outputs management:
  - Get all agent outputs
  - Get outputs for lead with no outputs
  - Update DESIGN agent output
  - Cross-user access prevention
  - Invalid agent name validation
  - Output data verification
- **run_agents_error.feature** - Error handling for agent execution
- **update_agent_output_writer.feature** - Update WRITER agent output
- **update_agent_output_search.feature** - Update SEARCH agent output
- **lead_stage_progression.feature** - Lead stage progression tracking:
  - Initial queued stage
  - Progression through stages (searched, written, critiqued)
  - Quality score updates
  - Stage persistence on agent failure

### Email Functionality
- **email_sending.feature** - Email sending functionality:
  - Send emails to ready leads
  - Handle no ready leads
  - Fallback to WRITER output when DESIGN not available
  - Cross-user access prevention
  - Error handling for failed sends

### API Key Management
- **api_keys_management.feature** - Basic API key management
- **api_keys_validation.feature** - API key validation and management:
  - Update API keys
  - Get stored API keys
  - Update individual keys
  - Clear API keys

### UI & Layout
- **dashboard_empty_state.feature** - Dashboard empty state handling
- **ui_layout_assets.feature** - UI asset loading
- **ui_layout_title_meta.feature** - Page title and meta tags
- **ui_pwa_icons.feature** - PWA icon loading
- **ui_react_mount.feature** - React component mounting
- **ui_interactions.feature** - Comprehensive UI interactions:
  - React component rendering
  - Empty state display
  - Campaign list display
  - Page title and meta tags
  - Asset loading
  - PWA icons
  - CSS class verification

## Step Definitions

### common_steps.rb
Common step definitions for:
- User authentication
- Page navigation
- API request/response handling
- JSON response validation
- UI element verification
- Path resolution

### api_setup_steps.rb
API-specific step definitions for:
- Campaign setup
- Lead setup
- Agent output setup
- Agent config setup
- API key management
- Stage progression
- Agent execution
- Validation scenarios

## Running Tests

```bash
# Run all Cucumber tests
bundle exec cucumber

# Run specific feature
bundle exec cucumber features/authentication.feature

# Run with format
bundle exec cucumber --format pretty

# Run with tags
bundle exec cucumber --tags @smoke
```

## Test Coverage

The Cucumber test suite covers:
- ✅ Authentication and authorization
- ✅ Campaign CRUD operations
- ✅ Lead CRUD operations
- ✅ Agent configuration management
- ✅ Agent execution workflows
- ✅ Agent output management
- ✅ Email sending
- ✅ API key management
- ✅ Input validation
- ✅ Error handling
- ✅ UI interactions
- ✅ Data isolation and security
- ✅ Stage progression
- ✅ Campaign-leads relationships

### Coverage Analysis

For detailed coverage analysis and gap identification, see **[COVERAGE_ANALYSIS.md](./COVERAGE_ANALYSIS.md)**.

**Current Statistics:**
- **96 scenarios** with **497 steps** - **100% passing** ✅
- **19/19 API endpoints** covered (100%)
- **38 feature files** covering all major functionality

The coverage analysis document provides:
- Complete endpoint coverage mapping
- Identified gaps and missing scenarios
- Recommendations for improvement
- Tools and methods for coverage analysis
- Coverage metrics and statistics

## Notes

- Tests use `DISABLE_AUTH=true` by default (configured in `features/support/env.rb`)
- Tests create test data automatically using step definitions
- Tests clean up after themselves using database transactions
- All API endpoints are tested for both success and error cases
- Cross-user access prevention is thoroughly tested
- Input validation is tested for all required fields

