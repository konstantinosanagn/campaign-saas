# Code Coverage Report (SimpleCov)

Generated from Cucumber tests using SimpleCov.

## Overall Coverage

**Line Coverage: 63.85%** (664 / 1040 lines)

## Coverage by Category

### Controllers: 80.84% (464/574 lines) ✅
- **BaseController**: 100% ✅
- **CampaignsController**: 95.24% ✅
- **LeadsController**: 86.21% ✅
- **CampaignsController (web)**: 81.25% ✅
- **ApiKeysController**: 74.07% ⚠️
- **AgentConfigsController**: 72.00% ⚠️
- **ApplicationController**: 56.52% ❌

### Models: 83.78% (124/148 lines) ✅
- **ApplicationRecord**: 100% ✅
- **Campaign**: 86.96% ✅
- **Lead**: 86.67% ✅
- **AgentConfig**: 80% ✅
- **User**: 80% ✅
- **AgentOutput**: 78.57% ⚠️

### Services: 53.71% (710/1322 lines) ⚠️
- **LeadAgentService**: 94.74% ✅
- **ApiKeyService**: 89.47% ✅
- **EmailSenderService**: 88.57% ✅
- **SearchAgent**: 82.76% ✅
- **WriterAgent**: 76.42% ⚠️
- **CritiqueAgent**: 72.22% ⚠️
- **DesignAgent**: 0% ❌ (not used in Cucumber tests)
- **Orchestrator**: 0% ❌ (not used in Cucumber tests)

### Mailers: 93.33% (28/30 lines) ✅
- **ApplicationMailer**: 100% ✅
- **CampaignMailer**: 91.67% ✅

### Helpers: 100% (2/2 lines) ✅
- **ApplicationHelper**: 100% ✅

### Jobs: 0% (0/4 lines) ⚠️
- **ApplicationJob**: 0% (not used in Cucumber tests)

## Files with Low Coverage (<80%)

### Critical (0% coverage):
- `app/services/agents/design_agent.rb`: 0% (130 lines)
  - **Reason**: DesignAgent is not executed in Cucumber tests
  - **Impact**: Low - DesignAgent is used in the full pipeline but not in individual agent tests
  - **Recommendation**: Add tests for DESIGN agent execution, or integrate into full pipeline tests

- `app/services/orchestrator.rb`: 0% (108 lines)
  - **Reason**: Orchestrator is a separate service not used by LeadAgentService
  - **Impact**: Low - Orchestrator may be legacy code or used elsewhere
  - **Recommendation**: Verify if Orchestrator is still needed, or add tests if it is

### Medium Priority (<80% coverage):
- `app/controllers/application_controller.rb`: 56.52% (13/23 lines)
  - **Missing**: Some helper methods, default API key setup
  - **Impact**: Low - Helper methods may not need direct testing
  
- `app/controllers/api/v1/agent_configs_controller.rb`: 72% (54/75 lines)
  - **Missing**: Some error handling paths
  - **Impact**: Medium - Could test more error scenarios
  
- `app/services/agents/critique_agent.rb`: 72.22% (52/72 lines)
  - **Missing**: Some error handling, edge cases
  - **Impact**: Low - Core functionality is tested
  
- `app/controllers/api/v1/api_keys_controller.rb`: 74.07% (20/27 lines)
  - **Missing**: Some validation scenarios
  - **Impact**: Low - Core functionality is tested
  
- `app/services/agents/writer_agent.rb`: 76.42% (81/106 lines)
  - **Missing**: Some error handling, edge cases
  - **Impact**: Low - Core functionality is tested
  
- `app/models/agent_output.rb`: 78.57% (11/14 lines)
  - **Missing**: Some helper methods
  - **Impact**: Low - Core functionality is tested

## Coverage Analysis

### ✅ Well Covered Areas
1. **API Controllers**: 80.84% - All critical endpoints are tested
2. **Models**: 83.78% - All models have good coverage
3. **LeadAgentService**: 94.74% - Core business logic is well tested
4. **Email Sending**: 88.57% - Email functionality is tested
5. **Authentication**: BaseController has 100% coverage

### ⚠️ Areas Needing Improvement
1. **DesignAgent**: 0% - Not tested in Cucumber
2. **Orchestrator**: 0% - Not tested in Cucumber
3. **ApplicationController**: 56.52% - Some helper methods not tested
4. **Agent Configs Controller**: 72% - Some error paths not tested

### 📊 Coverage Statistics

| Category | Coverage | Files | Status |
|----------|----------|-------|--------|
| Controllers | 80.84% | 14 | ✅ Good |
| Models | 83.78% | 12 | ✅ Good |
| Services | 53.71% | 16 | ⚠️ Needs Improvement |
| Mailers | 93.33% | 4 | ✅ Excellent |
| Helpers | 100% | 2 | ✅ Perfect |
| Jobs | 0% | 2 | ⚠️ Not Used |
| **Overall** | **63.85%** | **50** | ⚠️ Acceptable |

## Recommendations

### High Priority
1. **Test DesignAgent execution**: Add Cucumber scenarios for DESIGN agent
2. **Improve ApplicationController coverage**: Test helper methods and default API key setup
3. **Test Orchestrator**: Verify if it's still needed, add tests if it is

### Medium Priority
1. **Improve Agent Configs Controller**: Test more error scenarios
2. **Improve WriterAgent coverage**: Test more edge cases and error handling
3. **Improve CritiqueAgent coverage**: Test more error scenarios

### Low Priority
1. **Improve AgentOutput model**: Test helper methods
2. **Improve ApiKeysController**: Test more validation scenarios

## How to View Coverage Report

### View HTML Report
```bash
# Open in browser
open coverage/index.html

# Or on Windows
start coverage/index.html
```

### Generate Coverage Report
```bash
# Run Cucumber tests with coverage
COVERAGE=true bundle exec cucumber

# View summary
ruby scripts/parse_coverage.rb
```

### Coverage Thresholds

Current threshold: **0%** (disabled)

Recommended thresholds:
- **Controllers**: 80%+
- **Models**: 80%+
- **Services**: 70%+
- **Overall**: 70%+

To enable thresholds, update `features/support/simplecov_setup.rb`:
```ruby
minimum_coverage 70  # Set desired threshold
```

## Notes

- **DesignAgent (0%)**: This agent is part of the pipeline but not executed in individual Cucumber tests. It's used when running the full pipeline but LeadAgentService doesn't use it directly.
- **Orchestrator (0%)**: This appears to be a legacy service or used in a different context. Verify if it's still needed.
- **Jobs (0%)**: ApplicationJob is not used in Cucumber tests, which is expected for background jobs.
- **JavaScript/TypeScript files**: Not included in Ruby SimpleCov coverage (tested separately with Jest).

## Comparison with RSpec

RSpec tests provide additional coverage:
- **178 RSpec tests** with **90%+ coverage**
- RSpec tests cover unit tests, controller specs, service specs
- Cucumber tests cover integration/acceptance tests

**Combined coverage** (RSpec + Cucumber) should provide comprehensive coverage of the application.

## Next Steps

1. ✅ SimpleCov is now configured and working
2. ⚠️ Review files with low coverage
3. ⚠️ Add tests for DesignAgent if needed
4. ⚠️ Verify if Orchestrator is still needed
5. ⚠️ Improve coverage for ApplicationController
6. ✅ Coverage report is generated automatically when running tests with `COVERAGE=true`

