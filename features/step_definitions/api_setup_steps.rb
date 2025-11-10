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
