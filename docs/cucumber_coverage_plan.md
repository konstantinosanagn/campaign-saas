# Cucumber Coverage Plan - 100% Coverage

## Overview
This document tracks the uncovered lines identified in SimpleCov and the test scenarios needed to achieve 100% coverage.

## Coverage Gaps by Category

### Models (22 uncovered lines)

#### AgentConfig (4 lines)
- Line 26: Validation error when settings is not a Hash
- Line 38: `enabled?` method when enabled is true
- Line 47: `get_setting` with symbol key fallback
- Line 51: `set_setting` method

#### JsonbValidator (13 lines)
- Lines 40-41: Empty hash/array validation with allow_empty=true
- Lines 57-59: Strict required properties validation
- Lines 79, 84, 87, 88, 92, 97: Property type validation errors (string, integer, boolean, array, object)
- Lines 105-106: Array schema validation error

#### Campaign (3 lines)
- Line 16: Default shared_settings when nil/empty
- Line 28: brand_voice fallback when missing
- Line 35: primary_goal fallback when missing

#### Lead (2 lines)
- Line 12: campaignId getter
- Line 16: campaignId setter

### Helpers (8 uncovered lines)

#### MarkdownHelper (8 lines)
- Lines 43-45: Blockquote handling with accumulated paragraph
- Lines 58-60: Bullet list handling with accumulated paragraph
- Lines 71-72: List closing when hitting non-list line

### Lib (2 uncovered lines)

#### CustomFailureApp (2 lines)
- Line 10: Production mode with signup path/referer
- Line 15: Production mode with non-user scope

### Controllers (82 uncovered lines)

#### ApplicationController (6 lines)
- Lines 16-17: Production mode path helpers
- Lines 20, 25-26, 29: Development mode path helpers

#### BaseController (3 lines)
- Line 20: Development mode skip_auth default
- Line 29: Devise::MissingWarden rescue
- Line 55: Non-skip_auth path (returns nil)

#### AgentConfigsController (16 lines)
- Lines 18, 41-42, 48-49: Error responses (campaign not found, config not found)
- Lines 70-71: Create error (campaign not found)
- Lines 114, 126-127, 133-134: Update/destroy errors
- Lines 151, 163-164, 188: Error responses and fallback params

#### LeadsController (19 lines)
- Line 41: Update error when lead not found
- Lines 142, 190, 195-197, 201, 203-204, 209, 215: run_agents error paths (async errors, sync errors, not found)
- Lines 241-242, 255-256, 265-266, 292-293: update_agent_output error paths

#### CampaignsController (8 lines)
- Lines 11-12: show action (campaign not found)
- Lines 24, 49, 51-52, 69, 72: current_user fallback paths (admin user creation/update)

#### Users::RegistrationsController (9 lines)
- Lines 28-30: Inactive account signup path
- Lines 72, 75-76, 82, 84, 100: Remember me checks and cookie clearing

#### Users::SessionsController (8 lines)
- Lines 32, 61, 99, 102-103, 109, 111, 122: Remember me clearing paths

#### Api::V1::CampaignsController (8 lines)
- Lines 46, 48-50, 54, 56, 63, 87: Error paths and shared_settings merging

#### Api::V1::ApiKeysController (5 lines)
- Lines 8-9, 22-23, 51: Unauthorized and validation error paths

### Services (44 uncovered lines)

#### ApiKeyService (1 line)
- Line 37: Missing Tavily API key error

#### SearchAgent (3 lines)
- Lines 116, 122-123: Error handling in run_tavily_search

#### WriterAgent (18 lines)
- Line 124: Missing candidate/content/parts in response
- Line 144: Error rescue path
- Lines 164-166, 170-176, 183, 198, 213, 227, 240, 251: Various prompt building branches (sender_company, product_info, sources, focus_areas, personalization levels, tone, email_length, CTA types, CTA softness)

#### CritiqueAgent (9 lines)
- Line 59: Default strictness case
- Lines 142-143: Network error rescue
- Lines 158, 167, 221-222, 225, 229: Variant selection and score extraction paths

#### DesignAgent (2 lines)
- Lines 112, 127: Error handling paths

#### EmailSenderService (2 lines)
- Lines 164-165: Error handling paths

#### GmailOauthService (5 lines)
- Lines 51, 106, 111, 152, 181: Error handling and edge cases

#### LeadAgentService (4 lines)
- Lines 253, 383-384, 386: Default agent config and extract_domain edge cases

### Jobs (5 uncovered lines)

#### AgentExecutionJob (5 lines)
- Lines 38-39: Ownership verification failures
- Lines 61-63: Exception handling and re-raise

## Test Strategy

### Approach 1: Full Cucumber Scenarios
Use for:
- API controller error paths
- User authentication flows
- HTML controller actions

### Approach 2: Step Definitions with Mocks
Use for:
- Service error handling
- External API failures
- Background job error paths

### Approach 3: Coverage Harness
Use for:
- Model methods that need direct invocation
- Helper methods
- Edge cases in validations

## Implementation Checklist

- [ ] Models: AgentConfig validation and methods
- [ ] Models: JsonbValidator all validation paths
- [ ] Models: Campaign default methods
- [ ] Models: Lead camelCase methods
- [ ] Helpers: MarkdownHelper edge cases
- [ ] Lib: CustomFailureApp production paths
- [ ] Controllers: ApplicationController path helpers
- [ ] Controllers: BaseController auth edge cases
- [ ] Controllers: AgentConfigsController error paths
- [ ] Controllers: LeadsController error paths
- [ ] Controllers: CampaignsController error paths
- [ ] Controllers: Users controllers remember_me paths
- [ ] Controllers: Api::V1::CampaignsController error paths
- [ ] Controllers: Api::V1::ApiKeysController error paths
- [ ] Services: All error handling paths
- [ ] Jobs: AgentExecutionJob error paths

