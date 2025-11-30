# Testing Batch Processing - Verification Guide

## Overview

This guide shows how to verify that batch processing is properly wired and working correctly.

---

## Test Coverage

### ✅ Service Tests

**File:** `spec/services/batch_lead_processing_service_spec.rb`

Tests:
- ✅ Enqueues jobs for all valid leads
- ✅ Returns success result with queued leads
- ✅ Includes job IDs in response
- ✅ Handles invalid campaign ownership
- ✅ Filters leads from different campaigns
- ✅ Handles empty/invalid lead IDs
- ✅ Error handling when job enqueue fails
- ✅ Large batch processing
- ✅ Synchronous processing (for development/testing)

### ✅ API Endpoint Tests

**File:** `spec/requests/api/v1/leads_controller_spec.rb`

Tests:
- ✅ Returns accepted status
- ✅ Enqueues jobs for all leads
- ✅ Returns success response with queued leads
- ✅ Includes job IDs in response
- ✅ Custom batch size support
- ✅ Missing API keys validation
- ✅ Campaign ownership validation
- ✅ Parameter validation (missing leadIds, campaignId)
- ✅ Filters leads from different campaigns
- ✅ Authentication required

---

## Running Tests

### Run All Tests

```bash
# Run all tests
bundle exec rspec

# Run service tests only
bundle exec rspec spec/services/batch_lead_processing_service_spec.rb

# Run API endpoint tests only
bundle exec rspec spec/requests/api/v1/leads_controller_spec.rb
```

### Run Specific Test

```bash
# Run specific test file
bundle exec rspec spec/services/batch_lead_processing_service_spec.rb:13

# Run with verbose output
bundle exec rspec spec/services/batch_lead_processing_service_spec.rb --format documentation
```

---

## Manual Testing

### 1. Test Service Directly (Rails Console)

```ruby
# Start Rails console
rails console

# Setup test data
user = User.first
campaign = user.campaigns.first
lead_ids = campaign.leads.limit(5).pluck(:id)

# Test batch processing
result = BatchLeadProcessingService.process_leads(lead_ids, campaign, user)

# Check results
puts "Total: #{result[:total]}"
puts "Queued: #{result[:queued_count]}"
puts "Failed: #{result[:failed_count]}"
puts "Queued Leads: #{result[:queued]}"

# Verify jobs were enqueued
ActiveJob::Base.queue_adapter.enqueued_jobs.count
```

### 2. Test API Endpoint (cURL)

```bash
# Get auth token (if using token auth) or use session
# Replace <TOKEN> with actual auth token

curl -X POST http://localhost:3000/api/v1/leads/batch_run_agents \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "leadIds": [1, 2, 3],
    "campaignId": 1,
    "batchSize": 10
  }'
```

### 3. Test API Endpoint (Rails Console)

```ruby
# Start Rails console
rails console

# Setup
user = User.first
campaign = user.campaigns.first
lead_ids = campaign.leads.limit(3).pluck(:id)

# Simulate API request
app.post '/api/v1/leads/batch_run_agents',
  params: {
    leadIds: lead_ids,
    campaignId: campaign.id,
    batchSize: 10
  }.to_json,
  headers: {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }

# Check response
response.status  # Should be 202 (accepted)
json = JSON.parse(response.body)
puts json
```

---

## Verification Checklist

### Service Layer

- [ ] `BatchLeadProcessingService.process_leads` exists and works
- [ ] Jobs are enqueued correctly
- [ ] Returns proper result structure
- [ ] Handles errors gracefully
- [ ] Filters invalid leads

### API Endpoint

- [ ] Route exists: `POST /api/v1/leads/batch_run_agents`
- [ ] Endpoint accepts request
- [ ] Returns 202 Accepted status
- [ ] Validates parameters
- [ ] Checks authorization
- [ ] Enqueues background jobs

### Background Jobs

- [ ] `AgentExecutionJob` processes correctly
- [ ] Jobs can be executed
- [ ] Error handling works

### Integration

- [ ] Service → API endpoint integration works
- [ ] API endpoint → Background job integration works
- [ ] End-to-end flow works

---

## Test Scenarios

### Scenario 1: Basic Batch Processing

```ruby
# Setup
user = User.first
campaign = user.campaigns.first
lead_ids = [1, 2, 3]

# Execute
result = BatchLeadProcessingService.process_leads(lead_ids, campaign, user)

# Verify
expect(result[:total]).to eq(3)
expect(result[:queued_count]).to eq(3)
expect(result[:failed_count]).to eq(0)
```

### Scenario 2: Large Batch

```ruby
# Create 25 leads
lead_ids = Array.new(25) { create(:lead, campaign: campaign).id }

# Execute
result = BatchLeadProcessingService.process_leads(lead_ids, campaign, user)

# Verify
expect(result[:queued_count]).to eq(25)
expect(ActiveJob::Base.queue_adapter.enqueued_jobs.count).to eq(25)
```

### Scenario 3: Error Handling

```ruby
# Invalid campaign
other_campaign = create(:campaign, user: other_user)
result = BatchLeadProcessingService.process_leads([1, 2], other_campaign, user)

# Verify
expect(result[:error]).to be_present
expect(result[:total]).to eq(0)
```

---

## Debugging

### Check Job Queue

```ruby
# Rails console
ActiveJob::Base.queue_adapter.enqueued_jobs
ActiveJob::Base.queue_adapter.enqueued_jobs.count

# Check specific job
jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
jobs.select { |j| j[:job] == AgentExecutionJob }
```

### Check Logs

```bash
# Development logs
tail -f log/development.log

# Test logs
tail -f log/test.log
```

### Verify Configuration

```ruby
# Rails console
ActiveJob::Base.queue_adapter.class
# Should return: ActiveJob::QueueAdapters::TestAdapter

# In production, should be:
# ActiveJob::QueueAdapters::SidekiqAdapter (or similar)
```

---

## Expected Behavior

### Successful Batch Processing

1. **Service Call:**
   ```ruby
   result = BatchLeadProcessingService.process_leads(lead_ids, campaign, user)
   ```
   - Returns hash with `total`, `queued_count`, `queued`, `failed`
   - All leads should have `job_id` in `queued` array

2. **API Call:**
   ```http
   POST /api/v1/leads/batch_run_agents
   ```
   - Returns 202 Accepted
   - Response includes `queuedLeads` with job IDs
   - Jobs are enqueued in background

3. **Job Execution:**
   - Jobs are processed by background worker
   - Each job runs `LeadAgentService.run_agents_for_lead`
   - Agent outputs are stored in database
   - Lead stages are updated

---

## Troubleshooting

### Issue: Jobs not enqueuing

**Check:**
- ActiveJob adapter is set to `:test` in test environment
- `ActiveJob::TestHelper` is included in spec helper
- Queue adapter is properly configured

**Fix:**
```ruby
# In rails_helper.rb (already added)
config.include ActiveJob::TestHelper, type: :request

# In config/environments/test.rb (already added)
config.active_job.queue_adapter = :test
```

### Issue: Tests failing with "undefined method have_enqueued_job"

**Fix:**
- Ensure `ActiveJob::TestHelper` is included
- Ensure test environment uses `:test` adapter

### Issue: Jobs not processing in development

**Check:**
- Background job worker is running
- Queue adapter is configured (Redis/Sidekiq)

**Run worker:**
```bash
# If using Sidekiq
bundle exec sidekiq

# If using default adapter, jobs run inline
```

---

## Next Steps After Testing

1. ✅ Run test suite: `bundle exec rspec`
2. ✅ Verify all tests pass
3. ✅ Test manually in development environment
4. ✅ Deploy to staging for integration testing
5. ✅ Monitor job processing in production

---

*Last Updated: 2025-12-01*
