Given('a campaign exists for the user') do
  @user ||= User.create!(email: 'user@example.com', password: 'password')
  @campaign = Campaign.create!(title: 'Test Campaign', user: @user)
end

Given('the campaign has leads') do
  @leads = 3.times.map do |i|
    Lead.create!(
      campaign: @campaign,
      email: "lead#{i}@example.com",
      name: "Lead #{i}",
      title: "Title #{i}",
      company: "Company #{i}"
    )
  end
end

When('I process all leads in the campaign using the batch lead processing service') do
  @result = BatchLeadProcessingService.process_leads(@leads.map(&:id), @campaign, @user)
end

When('I process all leads in the campaign synchronously using the batch lead processing service') do
  allow(LeadAgentService).to receive(:run_agents_for_lead).and_return({ status: 'completed', completed_agents: [ 'A' ] })
  @sync_result = BatchLeadProcessingService.process_leads_sync(@leads.map(&:id), @campaign, @user)
end

Then('all leads should be completed synchronously') do
  expect(@sync_result[:completed].map { |c| c[:lead_id] }).to match_array(@leads.map(&:id))
end

Then('the sync result should include the correct total and completed count') do
  expect(@sync_result[:total]).to eq(@leads.size)
  expect(@sync_result[:completed_count]).to eq(@leads.size)
end

When('the user tries to process leads synchronously using the batch lead processing service') do
  @sync_result = BatchLeadProcessingService.process_leads_sync(@leads.map(&:id), @campaign, @user)
end

Then('no leads should be processed synchronously') do
  expect(@sync_result[:completed]).to be_empty
  expect(@sync_result[:failed]).to be_empty
end

Given('the environment variable BATCH_SIZE is set to {int}') do |val|
  stub_const('ENV', ENV.to_hash.merge('BATCH_SIZE' => val.to_s))
end

When('I get the recommended batch size from the batch lead processing service') do
  @recommended_batch_size = BatchLeadProcessingService.recommended_batch_size
end

Then('the recommended batch size should be {int}') do |expected|
  expect(@recommended_batch_size).to eq(expected)
end

Given('the environment variable BATCH_SIZE is not set') do
  stub_const('ENV', ENV.to_hash.reject { |k, _| k == 'BATCH_SIZE' })
end

Given('Rails is in production environment') do
  allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
end

Given('Rails is in development environment') do
  allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
end

Then('all leads should be queued for processing') do
  expect(@result[:queued].map { |q| q[:lead_id] }).to match_array(@leads.map(&:id))
end

Then('the result should include the correct total and queued count') do
  expect(@result[:total]).to eq(@leads.size)
  expect(@result[:queued_count]).to eq(@leads.size)
end

Given('some leads will fail to enqueue') do
  allow(AgentExecutionJob).to receive(:perform_later).and_wrap_original do |m, *args|
    lead_id = args[0]
    if lead_id == @leads.first.id
      raise StandardError, 'Enqueue failed'
    else
      m.call(*args)
    end
  end
end

Then('the result should include failed leads') do
  expect(@result[:failed].map { |f| f[:lead_id] }).to include(@leads.first.id)
end

Then('the failed count should be correct') do
  expect(@result[:failed_count]).to eq(1)
end

Given('the campaign has no valid leads') do
  @leads = []
end

When('I process leads using the batch lead processing service') do
  @result = BatchLeadProcessingService.process_leads(@leads.map(&:id), @campaign, @user)
end

Then('the result should include an error message') do
  result = @result || @sync_result
  expect(result[:error]).to be_present
end

Then('the completed, failed, and queued lists should be empty') do
  expect(@result[:completed]).to be_empty
  expect(@result[:failed]).to be_empty
  expect(@result[:queued]).to be_empty
end

Given('a user that does not own the campaign') do
  @user = User.create!(email: 'other@example.com', password: 'password')
end

When('the user tries to process leads using the batch lead processing service') do
  @result = BatchLeadProcessingService.process_leads(@leads.map(&:id), @campaign, @user)
end

Then('no leads should be processed') do
  expect(@result[:completed]).to be_empty
  expect(@result[:failed]).to be_empty
  expect(@result[:queued]).to be_empty
end
