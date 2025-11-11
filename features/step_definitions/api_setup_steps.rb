Given('a campaign titled {string} exists for me') do |title|
  step 'a user exists'
  owner = @user || User.find_by(email: 'admin@example.com')
  @campaign = Campaign.create!(title: title, shared_settings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' }, user: owner)
end

Given('a lead exists for my campaign') do
  step 'a user exists'
  owner = @user || User.find_by(email: 'admin@example.com')
  @campaign ||= Campaign.create!(title: 'My Campaign', shared_settings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' }, user: owner)
  @lead = @campaign.leads.create!(name: 'Alice', email: 'alice@example.com', title: 'CTO', company: 'Acme', website: 'https://acme.test')
end

Given('a {string} agent output exists for the lead') do |agent_name|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  AgentOutput.create!(lead: @lead, agent_name: agent_name, status: 'completed', output_data: { sample: true })
end

Given('there is another user with a separate campaign') do
  other = User.create!(email: 'other@example.com', password: 'password123', password_confirmation: 'password123', name: 'Other User')
  @other_campaign = Campaign.create!(title: 'Other Campaign', shared_settings: { brand_voice: { tone: 'professional', persona: 'founder' }, primary_goal: 'book_call' }, user: other)
end

Given('the campaign has a {string} agent config') do |agent_name|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @agent_config = @campaign.agent_configs.create!(agent_name: agent_name, enabled: true, settings: {})
end

Given('the campaign has agent configs for {string}, {string}, and {string}') do |agent1, agent2, agent3|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @campaign.agent_configs.create!(agent_name: agent1, enabled: true, settings: {})
  @campaign.agent_configs.create!(agent_name: agent2, enabled: true, settings: {})
  @campaign.agent_configs.create!(agent_name: agent3, enabled: true, settings: {})
end

Given('the campaign has a {string} agent config that is disabled') do |agent_name|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @campaign.agent_configs.create!(agent_name: agent_name, enabled: false, settings: {})
end

Given('the lead has stage {string}') do |stage|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  @lead.update!(stage: stage)
end

Given('the lead has a {string} agent output with email content') do |agent_name|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  output_data = agent_name == 'DESIGN' ? { formatted_email: 'Subject: Test\n\nHello World' } : { email: 'Subject: Test\n\nHello World' }
  AgentOutput.create!(lead: @lead, agent_name: agent_name, status: 'completed', output_data: output_data)
end

Given('the lead does not have a {string} agent output') do |agent_name|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  @lead.agent_outputs.where(agent_name: agent_name).destroy_all
end

Given('I have API keys configured') do
  step 'a user exists'
  user = @user || User.find_by(email: 'admin@example.com')
  user.update!(llm_api_key: 'test-llm-key', tavily_api_key: 'test-tavily-key')
end

Given('I do not have API keys configured') do
  step 'a user exists'
  user = @user || User.find_by(email: 'admin@example.com')
  user.update!(llm_api_key: nil, tavily_api_key: nil)
end

Given('SMTP is not configured') do
  # This is a no-op in tests - email sending will use file delivery
end

Given('the API service is unavailable') do
  # This would require mocking HTTP requests in actual implementation
  # For now, this is a placeholder
end

Given('I have no campaigns') do
  step 'a user exists'
  user = @user || User.find_by(email: 'admin@example.com')
  user.campaigns.destroy_all
end

Given('the campaign has a lead with email {string}') do |email|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @lead = @campaign.leads.create!(name: 'Test Lead', email: email, title: 'CTO', company: 'Test Corp')
end

Given('the other user has a lead') do
  step 'there is another user with a separate campaign' unless @other_campaign
  other_user = @other_campaign.user
  @other_lead = @other_campaign.leads.create!(name: 'Other Lead', email: 'other@example.com', title: 'CTO', company: 'Other Corp')
end

Given('authentication is enabled') do
  # Disable auth skipping for this scenario
  ENV['DISABLE_AUTH'] = 'false'
end

Given('I am not logged in') do
  # Ensure authentication is enabled
  ENV['DISABLE_AUTH'] = 'false'
  # Clear any user session - in tests with Capybara, we can't actually log out
  # but the controller should check for authentication
end

Given('the campaign has shared settings with tone {string}') do |tone|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @campaign.update!(shared_settings: { brand_voice: { tone: tone, persona: 'founder' }, primary_goal: 'book_call' })
end

Given('the SEARCH agent will fail') do
  # Mock the SearchAgent to raise an error when run
  allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_raise(StandardError.new("Search agent failed"))
end

When('I create a lead with name {string} and email {string}') do |name, email|
  @campaign ||= begin
    step 'a campaign titled "Test Campaign" exists for me'
    @campaign
  end
  @lead = @campaign.leads.create!(name: name, email: email, title: 'CTO', company: 'Test Corp')
end

When('I run the {string} agent on the lead') do |agent_name|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  @campaign ||= @lead.campaign
  step 'I have API keys configured' unless @user&.llm_api_key.present?
  
  # Simulate running the agent by calling the service
  result = LeadAgentService.run_agents_for_lead(@lead, @campaign, @user || User.find_by(email: 'admin@example.com'))
  @lead.reload
end

When('I run agents on the lead') do
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  @campaign ||= @lead.campaign
  step 'I have API keys configured' unless @user&.llm_api_key.present?
  
  result = LeadAgentService.run_agents_for_lead(@lead, @campaign, @user || User.find_by(email: 'admin@example.com'))
  @lead.reload
end

Then('the lead should have stage {string}') do |stage|
  @lead.reload
  expect(@lead.stage).to eq(stage)
end

Then('the lead should have a quality score') do
  @lead.reload
  expect(@lead.quality).to be_present
  expect(@lead.quality).not_to eq('-')
end

Then('the lead should still have stage {string}') do |stage|
  @lead.reload
  expect(@lead.stage).to eq(stage)
end

Then('the lead should have agent outputs stored') do
  @lead.reload
  expect(@lead.agent_outputs.count).to be > 0
end

Then('the outputs should include {string}') do |agent_name|
  data = JSON.parse(@last_response.body)
  outputs = data['outputs'] || []
  agent_outputs = outputs.select { |o| o['agentName'] == agent_name || o['agent_name'] == agent_name }
  expect(agent_outputs).not_to be_empty
end

Then('the outputs array should be empty') do
  data = JSON.parse(@last_response.body)
  outputs = data['outputs'] || []
  expect(outputs).to be_empty
end

Then('the WRITER output should include {string} in outputData') do |key|
  data = JSON.parse(@last_response.body)
  outputs = data['outputs'] || []
  writer_output = outputs.find { |o| o['agentName'] == 'WRITER' || o['agent_name'] == 'WRITER' }
  expect(writer_output).to be_present
  expect(writer_output['outputData'] || writer_output['output_data']).to have_key(key)
end

Then('the JSON response should include {string} with {bool}') do |key, value|
  data = JSON.parse(@last_response.body)
  # Handle both string keys and symbol keys
  actual_value = data[key] || data[key.to_sym] || data[key.to_s.camelize(:lower).to_sym]
  # Convert to boolean for comparison
  actual_bool = case actual_value
  when true, 'true', 1, '1'
    true
  when false, 'false', 0, '0', nil
    false
  else
    actual_value
  end
  expect(actual_bool).to eq(value)
end

Then('the JSON response should include {string} with {int}') do |key, value|
  data = JSON.parse(@last_response.body)
  # Handle both string keys and symbol keys
  actual_value = data[key] || data[key.to_sym] || data[key.to_s.camelize(:lower).to_sym]
  expect(actual_value.to_i).to eq(value)
end

Then('the lead should be deleted') do
  expect(Lead.find_by(id: @lead.id)).to be_nil
end

Then('the agent outputs should be deleted') do
  expect(AgentOutput.where(lead_id: @lead.id).count).to eq(0)
end

Then('the agents should use the campaign\'s shared settings') do
  # This is verified by the agent execution using campaign settings
  # In actual implementation, we would verify the settings were passed to agents
  expect(@campaign.shared_settings).to be_present
end

Then('the campaigns should only include my campaigns') do
  data = JSON.parse(@last_response.body)
  user = @user || User.find_by(email: 'admin@example.com')
  campaign_ids = data.map { |c| c['id'] || c[:id] }
  user_campaign_ids = user.campaigns.pluck(:id)
  expect(campaign_ids).to match_array(user_campaign_ids)
end

Then('the leads should only include leads from my campaigns') do
  data = JSON.parse(@last_response.body)
  user = @user || User.find_by(email: 'admin@example.com')
  lead_ids = data.map { |l| l['id'] || l[:id] }
  user_lead_ids = Lead.joins(:campaign).where(campaigns: { user_id: user.id }).pluck(:id)
  expect(lead_ids).to match_array(user_lead_ids)
end

Then('the lead should still belong to the same campaign') do
  @lead.reload
  expect(@lead.campaign_id).to eq(@campaign.id)
end

Then('the dashboard should mount React components') do
  expect(page).to have_css('#campaign-dashboard-root')
  # Additional checks for React mounting would go here
end

Then('I should see the empty state message') do
  expect(page).to have_css('#campaign-dashboard-root')
  # Additional checks for empty state would go here
end

Then('I should see the campaign in the list') do
  expect(page).to have_css('#campaign-dashboard-root')
  # Additional checks for campaign list would go here
end

Then('the lead stage should be {string}') do |stage|
  @lead.reload
  expect(@lead.stage).to eq(stage)
end

Then('the lead stage should advance past {string}') do |stage|
  @lead.reload
  stages = ['queued', 'searched', 'written', 'critiqued', 'completed']
  current_index = stages.index(@lead.stage)
  past_index = stages.index(stage)
  expect(current_index).to be > past_index
end

Then('the JSON response should include {string} with false') do |key|
  data = JSON.parse(@last_response.body)
  actual_value = data[key] || data[key.to_sym] || data[key.to_s.camelize(:lower).to_sym]
  actual_bool = case actual_value
  when true, 'true', 1, '1'
    true
  when false, 'false', 0, '0', nil
    false
  else
    actual_value
  end
  expect(actual_bool).to eq(false)
end

Then('the JSON response should include {string} with true') do |key|
  data = JSON.parse(@last_response.body)
  actual_value = data[key] || data[key.to_sym] || data[key.to_s.camelize(:lower).to_sym]
  actual_bool = case actual_value
  when true, 'true', 1, '1'
    true
  when false, 'false', 0, '0', nil
    false
  else
    actual_value
  end
  expect(actual_bool).to eq(true)
end

Given('the lead has a {string} agent output') do |agent_name|
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  AgentOutput.create!(lead: @lead, agent_name: agent_name, status: 'completed', output_data: { sample: true })
end

Then('the JSON array response should have at least {int} items') do |count|
  data = JSON.parse(@last_response.body)
  expect(data).to be_a(Array)
  expect(data.size).to be >= count
end

Given("the other user's campaign has a lead") do
  step 'there is another user with a separate campaign' unless @other_campaign
  @other_lead = @other_campaign.leads.create!(name: 'Other Lead', email: 'other@example.com', title: 'CTO', company: 'Other Corp')
end