Given('sending email for lead id {int} will raise GmailAuthorizationError for default sender with message {string}') do |lead_id, message|
  # Only default sender raises GmailAuthorizationError, user cannot send via Gmail API
  allow(EmailSenderService).to receive(:new).and_call_original
  allow_any_instance_of(User).to receive(:send_gmail!) do |user, *args|
    if user.email == 'default@gmail.com'
      raise GmailAuthorizationError, message
    else
      # Simulate a successful send by calling the original method or do nothing
      # If the method is not implemented, just return nil
      begin
        super(user, *args)
      rescue NoMethodError
        nil
      end
    end
  end
end
Given('sending email for lead id {int} will succeed') do |id|
  allow_any_instance_of(EmailSenderService).to receive(:deliver_email).and_call_original
end

Given('there is no lead with id {int}') do |lead_id|
  Lead.where(id: lead_id).delete_all
end

Given('a lead exists with id {int}') do |lead_id|
  user = User.create!(email: "testuser#{lead_id}_#{SecureRandom.hex(4)}@notgmail.com", password: 'password123')
  campaign = Campaign.create!(title: "Test Campaign #{lead_id}_#{SecureRandom.hex(4)}", user: user)
  lead = Lead.create!(
    id: lead_id,
    name: "Test Lead #{lead_id}",
    email: "lead#{lead_id}_#{SecureRandom.hex(4)}@notgmail.com",
    title: "Title #{lead_id}",
    company: "Company #{lead_id}",
    campaign: campaign,
    email_status: 'pending',
    last_email_error_message: nil
  )
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(user).to receive(:smtp_configured?).and_return(true) rescue nil
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(ActionMailer::Base).to receive(:smtp_settings).and_return({ address: 'smtp.example.com', user_name: 'user', password: 'pass' }) rescue nil
end

Given('sending email for lead id {int} will raise a TemporaryEmailError with message {string}') do |lead_id, message|
  allow(EmailSenderService).to receive(:new).and_call_original
  allow_any_instance_of(EmailSenderService).to receive(:send_email_via_provider).and_raise(TemporaryEmailError, message)
end

Given('sending email for lead id {int} will raise a PermanentEmailError with message {string}') do |lead_id, message|
  allow(EmailSenderService).to receive(:new).and_call_original
  allow_any_instance_of(EmailSenderService).to receive(:send_email_via_provider).and_raise(PermanentEmailError, message)
end

When('the email sending job is performed for lead id {int}') do |lead_id|
  @log_output = StringIO.new
  logger = Logger.new(@log_output)
  allow(Rails).to receive(:logger).and_return(logger)
  begin
    EmailSendingJob.new.perform(lead_id)
  rescue TemporaryEmailError, PermanentEmailError, StandardError
    # Expected for these tests
  end
end

Then('a warning log should include {string}') do |expected|
  expect(@log_output.string).to include(expected)
end

Then('an error log should include {string}') do |expected|
  expect(@log_output.string).to include(expected)
end

Given('a lead with email status {string}') do |status|
  user = User.create!(email: "testuser_status_#{SecureRandom.hex(4)}@notgmail.com", password: 'password123')
  campaign = Campaign.create!(title: "Test Campaign Status #{SecureRandom.hex(4)}", user: user)
  @lead = Lead.create!(name: 'Test', email: "test_status_#{SecureRandom.hex(4)}@notgmail.com", title: 'Title', company: 'Company', campaign: campaign, email_status: status)
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(user).to receive(:smtp_configured?).and_return(true) rescue nil
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(ActionMailer::Base).to receive(:smtp_settings).and_return({ address: 'smtp.example.com', user_name: 'user', password: 'pass' }) rescue nil
end

When('I check if the lead email was sent') do
  @result = @lead.email_sent?
end

When('I check if the lead email is sending') do
  @result = @lead.email_sending?
end

When('I check if the lead email failed') do
  @result = @lead.email_failed?
end

When('I check if the lead email is not scheduled') do
  @result = @lead.email_not_scheduled?
end

Given('a lead exists with id {int}, stage {string}, and valid email content') do |id, stage|
  user = User.create!(email: "user#{id}_#{SecureRandom.hex(4)}@notgmail.com", password: 'password123')
  campaign = Campaign.create!(title: "Test Campaign #{id}_#{SecureRandom.hex(4)}", user: user)
  lead = Lead.create!(
    id: id,
    campaign: campaign,
    stage: stage,
    email: "lead#{id}_#{SecureRandom.hex(4)}@notgmail.com",
    name: "Test Lead #{id}",
    title: "Title #{id}",
    company: "Company #{id}"
  )
  create(:agent_output, lead: lead, agent_name: AgentConstants::AGENT_DESIGN, status: AgentConstants::STATUS_COMPLETED, output_data: { 'formatted_email' => 'Subject: Test\n\nHello!' })
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(user).to receive(:smtp_configured?).and_return(true) rescue nil
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(ActionMailer::Base).to receive(:smtp_settings).and_return({ address: 'smtp.example.com', user_name: 'user', password: 'pass' }) rescue nil
end

Given("the lead's campaign has a user who can send via Gmail API") do
  lead = Lead.last
  user = lead.campaign.user
  allow(user).to receive(:can_send_gmail?).and_return(true)
end

Then("the lead's last_email_sent_at should be set") do
  expect(Lead.last.last_email_sent_at).to be_present
end

Then("the lead's stage should be {string}") do |stage|
  expect(Lead.last.stage).to eq(stage)
end

Given('a lead exists with id {int}, stage {string}, and no email content') do |id, stage|
  user = User.create!(email: "user#{id}_#{SecureRandom.hex(4)}@notgmail.com", password: 'password123')
  campaign = Campaign.create!(title: "Test Campaign #{id}_#{SecureRandom.hex(4)}", user: user)
  lead = Lead.create!(
    id: id,
    campaign: campaign,
    stage: stage,
    email: "lead#{id}_#{SecureRandom.hex(4)}@notgmail.com",
    name: "Test Lead #{id}",
    title: "Title #{id}",
    company: "Company #{id}"
  )
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(user).to receive(:smtp_configured?).and_return(true) rescue nil
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(ActionMailer::Base).to receive(:smtp_settings).and_return({ address: 'smtp.example.com', user_name: 'user', password: 'pass' }) rescue nil
end

Then("the lead's email_status should not be {string}") do |status|
  expect(Lead.last.email_status).not_to eq(status)
end

Given("the lead's campaign has no user") do
  lead = Lead.last
  campaign = lead.campaign
  campaign.update(user: nil)
end

Given('a lead exists with id {int}, stage {string}, and only WRITER email content') do |id, stage|
  user = User.create!(email: "user#{id}_#{SecureRandom.hex(4)}@notgmail.com", password: 'password123')
  campaign = Campaign.create!(title: "Test Campaign #{id}_#{SecureRandom.hex(4)}", user: user)
  lead = Lead.create!(id: id, campaign: campaign, stage: stage, email: "lead#{id}_#{SecureRandom.hex(4)}@notgmail.com")
  create(:agent_output, lead: lead, agent_name: AgentConstants::AGENT_WRITER, status: AgentConstants::STATUS_COMPLETED, output_data: { 'email' => 'Writer email content' })
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(user).to receive(:smtp_configured?).and_return(true) rescue nil
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(ActionMailer::Base).to receive(:smtp_settings).and_return({ address: 'smtp.example.com', user_name: 'user', password: 'pass' }) rescue nil
end

Given("the lead's campaign user cannot send via Gmail API") do
  lead = Lead.last
  user = lead.campaign.user
  allow(user).to receive(:can_send_gmail?).and_return(false)
end

Given('a default Gmail sender is configured and can send') do
  allow(ENV).to receive(:[]).and_wrap_original do |m, key|
    if key == 'DEFAULT_GMAIL_SENDER'
      'default@gmail.com'
    else
      m.call(key)
    end
  end
  default_sender = create(:user, email: 'default@gmail.com')
  allow(default_sender).to receive(:can_send_gmail?).and_return(true)
  allow(default_sender).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  original_find_by = User.method(:find_by)
  allow(User).to receive(:find_by) do |args|
    if args.is_a?(Hash) && args[:email] == 'default@gmail.com'
      default_sender
    else
      original_find_by.call(args)
    end
  end
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
end

Then('an info log should include {string}') do |message|
  expect(@log_output.string).to include(message)
end

Given('no default Gmail sender is configured') do
  allow(ENV).to receive(:[]).and_wrap_original do |m, key|
    if key == 'DEFAULT_GMAIL_SENDER'
      nil
    else
      m.call(key)
    end
  end
end

Given('a lead exists with id {int}, stage {string}, email_status {string}, and valid email content') do |id, stage, email_status|
  @lead_id = id
  user = User.first || FactoryBot.create(:user, email: "user#{id}@notgmail.com")
  campaign = Campaign.first || FactoryBot.create(:campaign, user: user)
  lead = Lead.create!(id: id, campaign: campaign, stage: stage, email_status: email_status, name: "Test Lead ", email: "lead#{id}@notgmail.com", title: "Title", company: "Company")
  # Ensure the lead is ready: DESIGN output and completed stage
  AgentOutput.create!(lead: lead, agent_name: AgentConstants::AGENT_DESIGN, status: AgentConstants::STATUS_COMPLETED, output_data: { 'formatted_email' => 'Subject: Test\n\nHello!' })
  # Robust stubs for all delivery methods
  allow(CampaignMailer).to receive(:send_email).and_return(double(deliver_now: true))
  allow(ActionMailer::Base).to receive(:delivery_method=)
  allow(ActionMailer::Base).to receive(:perform_deliveries=)
  allow(user).to receive(:can_send_gmail?).and_return(true)
  allow(user).to receive(:send_gmail!).and_return({ 'id' => 'msgid', 'threadId' => 'thrid' })
  allow(ENV).to receive(:[]).and_wrap_original do |m, key|
    if key == 'DEFAULT_GMAIL_SENDER'
      nil
    else
      m.call(key)
    end
  end
  allow(User).to receive(:find_by) do |args|
    if args.is_a?(Hash) && args[:email] == 'default@gmail.com'
      nil
    else
      nil
    end
  end
end

Then("the lead's email_status should be {string}") do |status|
  lead = Lead.find_by(id: @lead_id) || Lead.last
  puts "Lead status after job: #{lead.email_status}, error: #{lead.last_email_error_message}, stage: #{lead.stage}, outputs: #{lead.agent_outputs.map(&:output_data)}"
  puts "Lead status after job: #{lead.email_status}, error: #{lead.last_email_error_message}"
  expect(lead.email_status).to eq(status)
end

Then("the lead's last_email_error_message should include {string}") do |message|
  lead = Lead.find_by(id: @lead_id) || Lead.last
  expect(lead.last_email_error_message).to include(message)
end

Then("the lead's last_email_sent_at should be updated") do
  lead = Lead.find_by(id: @lead_id) || Lead.last
  expect(lead.last_email_sent_at).to be_present
end

Given('sending email for lead id {int} will raise a generic error with message {string}') do |id, message|
  allow_any_instance_of(EmailSenderService).to receive(:deliver_email).and_raise(StandardError, message)
end
