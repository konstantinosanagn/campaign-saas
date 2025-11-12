Given('Gmail OAuth client is configured') do
  ENV['GMAIL_CLIENT_ID'] = 'test-client-id'
  ENV['GMAIL_CLIENT_SECRET'] = 'test-client-secret'
  ENV['MAILER_HOST'] = 'http://localhost:3000'
end

Given('Gmail OAuth client is not configured') do
  ENV.delete('GMAIL_CLIENT_ID')
  ENV.delete('GMAIL_CLIENT_SECRET')
end

Given('GmailOauthService will report oauth_configured for current user as {word}') do |value|
  step 'a user exists'
  bool = value == 'true'
  allow(GmailOauthService).to receive(:oauth_configured?).with(@user).and_return(bool)
end

Given('GmailOauthService will report oauth_configured for user {string} as {word}') do |email, value|
  step 'a user exists'
  other = User.find_by(email: email) || User.create!(email: email, password: 'password123', password_confirmation: 'password123', name: 'Other')
  bool = value == 'true'
  allow(GmailOauthService).to receive(:oauth_configured?) do |user|
    user.email == other.email ? bool : false
  end
end

Given('GmailOauthService will raise error when checking oauth_configured') do
  allow(GmailOauthService).to receive(:oauth_configured?).and_raise(StandardError.new('oauth service failure'))
end

Given('GmailOauthService will return authorization url {string}') do |url|
  allow(GmailOauthService).to receive(:authorization_url).and_return(url)
end

Given('GmailOauthService will return exchange result {word}') do |value|
  allow(GmailOauthService).to receive(:exchange_code_for_tokens).and_return(value == 'true')
end

When('I deliver a campaign email to {string} with recipient_name {string} and campaign_title {string} and from_email {string}') do |to, recipient_name, campaign_title, from_email|
  # Deliver directly using CampaignMailer
  ActionMailer::Base.deliveries.clear
  mail = CampaignMailer.send_email(to: to, recipient_name: recipient_name, email_content: '<p>Hello</p>', campaign_title: campaign_title, from_email: from_email)
  mail.deliver_now
end

When('I deliver a campaign email to {string} with recipient_name {string} and campaign_title {string}') do |to, recipient_name, campaign_title|
  ActionMailer::Base.deliveries.clear
  mail = CampaignMailer.send_email(to: to, recipient_name: recipient_name, email_content: '<p>Hello</p>', campaign_title: campaign_title)
  mail.deliver_now
end

Given('I set my send_from_email to {string}') do |email|
  step 'a user exists'
  @user.update!(send_from_email: email)
end

When('I attempt to get authorization url for GmailOauthService') do
  step 'a user exists'
  begin
    @last_result = GmailOauthService.authorization_url(@user)
    @last_exception = nil
  rescue => e
    @last_result = nil
    @last_exception = e
  end
end

Then('the last operation should have raised an error') do
  expect(@last_exception).to be_present
end

Then('the last operation should not have raised an error') do
  expect(@last_exception).to be_nil
  expect(@last_result).to be_present
end

Given('Signet client will provide authorization uri {string}') do |uri_str|
  fake = double('SignetClient')
  allow(fake).to receive(:authorization_uri).and_return(URI(uri_str))
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

Given('Signet exchange will succeed with tokens') do
  fake = double('SignetExchangeClient')
  # allow setting code
  allow(fake).to receive(:code=)
  allow(fake).to receive(:fetch_access_token!).and_return(true)
  allow(fake).to receive(:access_token).and_return('access-xyz')
  allow(fake).to receive(:refresh_token).and_return('refresh-abc')
  allow(fake).to receive(:expires_at).and_return((Time.current + 3600).to_i)
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

Given('Signet exchange will fail') do
  fake = double('SignetExchangeClientFail')
  allow(fake).to receive(:code=)
  allow(fake).to receive(:fetch_access_token!).and_raise(StandardError.new('exchange failed'))
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

Given('Signet exchange will succeed with expires_in and no refresh_token') do
  fake = double('SignetExchangeClientExpiresIn')
  allow(fake).to receive(:code=)
  allow(fake).to receive(:fetch_access_token!).and_return(true)
  allow(fake).to receive(:access_token).and_return('access-expires-in')
  allow(fake).to receive(:refresh_token).and_return(nil)
  allow(fake).to receive(:expires_at).and_return(nil)
  allow(fake).to receive(:expires_in).and_return(3600)
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

Given('GmailOauthService will return valid access token {string}') do |token|
  allow(GmailOauthService).to receive(:valid_access_token).and_return(token)
  allow(GmailOauthService).to receive(:oauth_configured?).and_return(true)
end

Given('Signet refresh will succeed with tokens') do
  fake = double('SignetRefreshClient')
  allow(fake).to receive(:refresh!).and_return(true)
  allow(fake).to receive(:access_token).and_return('refreshed-access-123')
  allow(fake).to receive(:expires_at).and_return(nil)
  allow(fake).to receive(:expires_in).and_return(1800)
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

Given('Signet refresh will fail') do
  fake = double('SignetRefreshClientFail')
  allow(fake).to receive(:refresh!).and_raise(StandardError.new('refresh failed'))
  allow(Signet::OAuth2::Client).to receive(:new).and_return(fake)
end

When('I request a valid access token for my user') do
  step 'a user exists'
  begin
    @last_result = GmailOauthService.valid_access_token(@user)
    @last_exception = nil
  rescue => e
    @last_result = nil
    @last_exception = e
  end
end

When('I set ENV var {string} to {string}') do |key, value|
  ENV[key] = value
end

Then('the last operation should have returned false') do
  expect(@last_result).to eq(false)
  expect(@last_exception).to be_nil
end

Then('the last result should be nil') do
  expect(@last_result).to be_nil
end

Given('Gmail API will respond with {int} and body {string}') do |code, body|
  fake_http = double('Net::HTTP')
  fake_response = double('Net::HTTPResponse', code: code.to_s, body: body)
  allow(fake_http).to receive(:use_ssl=)
  allow(fake_http).to receive(:verify_mode=)
  allow(fake_http).to receive(:request).and_return(fake_response)
  allow(Net::HTTP).to receive(:new).and_return(fake_http)
end

Given('SMTP environment is configured') do
  ENV['SMTP_ADDRESS'] = 'smtp.test'
  ENV['SMTP_PASSWORD'] = 'pass'
  ENV['SMTP_USER_NAME'] = 'smtp-user'
  ENV['SMTP_PORT'] = '587'
  ENV['SMTP_DOMAIN'] = 'testdomain'
end

Given('CampaignMailer delivery will succeed') do
  allow(CampaignMailer).to receive(:send_email) do |**kwargs|
    mail_double = double('Mail::Message')
    allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
    allow(mail_double).to receive(:deliver_now) do
      delivered = Mail::Message.new
      # try to set 'to' on delivered message from kwargs
      to_val = kwargs[:to] || kwargs['to'] || (kwargs.is_a?(Hash) && kwargs[:to])
      delivered.to = Array(to_val).compact
      ActionMailer::Base.deliveries << delivered
      true
    end
    mail_double
  end
end

When('I run EmailSenderService for the campaign') do
  @last_result = EmailSenderService.send_emails_for_campaign(@campaign)
end

When('I attempt to send email for lead {string}') do |email|
  @lead ||= @campaign.leads.find_by(email: email) || @campaign.leads.create!(name: 'Tmp', email: email, title: 'CTO', company: 'X')
  @last_send = EmailSenderService.send_email_for_lead(@lead)
end

When('I attempt to send email for my lead') do
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  @last_send = EmailSenderService.send_email_for_lead(@lead)
end

Then('the last email send should have failed with message containing {string}') do |text|
  expect(@last_send).to be_present
  expect(@last_send[:success]).to eq(false)
  expect(@last_send[:error].downcase).to include(text)
end

Then('the last email send should have failed with an SMTP error') do
  expect(@last_send).to be_present
  expect(@last_send[:success]).to eq(false)
  expect(@last_send[:error]).to match(/smtp/i)
end

Given('CampaignMailer delivery will raise an SMTP error') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new('SMTP fail'))
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Then('the send result should have sent {int}') do |count|
  expect(@last_result).to be_present
  expect(@last_result[:sent]).to eq(count)
end

When('I exchange code {string} for tokens for my user') do |code|
  step 'a user exists'
  begin
    @last_exchange_result = GmailOauthService.exchange_code_for_tokens(@user, code)
    @last_result = @last_exchange_result
    @last_exception = nil
  rescue => e
    @last_exchange_result = nil
    @last_exception = e
  end
end

When("I set the user's gmail_refresh_token to {string}") do |token|
  step 'a user exists'
  @user.update_column(:gmail_refresh_token, token)
end

When("I set the user's gmail_token_expires_at to {string}") do |ts|
  step 'a user exists'
  @user.update_column(:gmail_token_expires_at, Time.parse(ts))
end

When('I remove campaign from lead') do
  @lead ||= begin
    step 'a lead exists for my campaign'
    @lead
  end
  allow(@lead).to receive(:campaign).and_return(nil)
end

When('I remove user from campaign') do
  allow(@campaign).to receive(:user).and_return(nil) if @campaign
end

Then('the send result should have failed {int}') do |count|
  expect(@last_result).to be_present
  expect(@last_result[:failed]).to eq(count)
end

Given('CampaignMailer delivery will fail for lead {string}') do |email|
  allow(CampaignMailer).to receive(:send_email) do |**kwargs|
    to_email = kwargs[:to] || kwargs['to']
    mail_double = double('Mail::Message')
    allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")

    if to_email == email
      allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new("Delivery failed for #{email}"))
    else
      allow(mail_double).to receive(:deliver_now) do
        delivered = Mail::Message.new
        delivered.to = Array(to_email).compact
        ActionMailer::Base.deliveries << delivered
        true
      end
    end
    mail_double
  end
end

Given('CampaignMailer delivery will raise a connection timeout error') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
  allow(mail_double).to receive(:deliver_now).and_raise(Errno::ETIMEDOUT.new('Connection timed out'))
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Given('CampaignMailer delivery will raise an SSL error') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
  allow(mail_double).to receive(:deliver_now).and_raise(OpenSSL::SSL::SSLError.new('SSL handshake failed'))
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Then('the last email send should have failed with an error') do
  expect(@last_send).to be_present
  expect(@last_send[:success]).to eq(false)
  expect(@last_send[:error]).to be_present
end

Given('GmailOauthService will return valid access token nil') do
  allow(GmailOauthService).to receive(:valid_access_token).and_return(nil)
  allow(GmailOauthService).to receive(:oauth_configured?).and_return(true)
end

Given('CampaignMailer delivery will raise exception for lead {string}') do |email|
  # Track which emails should fail
  @failing_emails ||= []
  @failing_emails << email

  allow(CampaignMailer).to receive(:send_email) do |**kwargs|
    to_email = kwargs[:to] || kwargs['to']
    mail_double = double('Mail::Message')
    allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")

    if @failing_emails.include?(to_email)
      allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new("Unexpected exception for #{to_email}"))
    else
      allow(mail_double).to receive(:deliver_now) do
        delivered = Mail::Message.new
        delivered.to = Array(to_email).compact
        ActionMailer::Base.deliveries << delivered
        true
      end
    end
    mail_double
  end
end

Given('there is another user with email {string}') do |email|
  @other_user = User.find_by(email: email) || User.create!(
    email: email,
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Other User'
  )
end

Given('the other user has OAuth configured') do
  @other_user ||= User.find_by(email: 'admin@example.com')
  @other_user.update!(
    gmail_refresh_token: 'refresh-token-xyz',
    gmail_access_token: 'access-token-xyz',
    gmail_token_expires_at: 1.hour.from_now
  )
end

Given('GmailOauthService will report oauth_configured for other user as {word}') do |value|
  @other_user ||= User.last
  bool = value == 'true'
  allow(GmailOauthService).to receive(:oauth_configured?) do |user|
    user.id == @other_user.id ? bool : false
  end
end

Given('GmailOauthService will return valid access token {string} for other user') do |token|
  @other_user ||= User.last
  allow(GmailOauthService).to receive(:valid_access_token) do |user|
    user.id == @other_user.id ? token : nil
  end
end

Given('Gmail API HTTP request will raise connection error') do
  fake_http = double('Net::HTTP')
  allow(fake_http).to receive(:use_ssl=)
  allow(fake_http).to receive(:verify_mode=)
  allow(fake_http).to receive(:request).and_raise(Errno::ECONNREFUSED.new('Connection refused'))
  allow(Net::HTTP).to receive(:new).and_return(fake_http)
end

Then('the last email send should have succeeded') do
  expect(@last_send).to be_present
  expect(@last_send[:success]).to eq(true)
end

Then('the success message should contain {string}') do |text|
  expect(@last_send).to be_present
  expect(@last_send[:message]).to include(text)
end

Given('CampaignMailer delivery will raise SMTP authentication error with response') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")

  # Create a mock response object
  response_double = double('SMTPResponse')
  allow(response_double).to receive(:code).and_return('535')
  allow(response_double).to receive(:message).and_return('Authentication failed')

  error = Net::SMTPAuthenticationError.new('Authentication failed')
  allow(error).to receive(:response).and_return(response_double)

  allow(mail_double).to receive(:deliver_now).and_raise(error)
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Given('CampaignMailer delivery will raise Net::SMTPError') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")

  error = Net::SMTPServerBusy.new('450 Temporary failure')

  # Create a mock response object
  response_double = double('SMTPResponse')
  allow(response_double).to receive(:inspect).and_return('SMTP error response')
  allow(error).to receive(:response).and_return(response_double)

  allow(mail_double).to receive(:deliver_now).and_raise(error)
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Given('CampaignMailer delivery will raise connection refused error') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
  allow(mail_double).to receive(:deliver_now).and_raise(Errno::ECONNREFUSED.new('Connection refused'))
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Given('CampaignMailer delivery will raise Timeout::Error') do
  mail_double = double('Mail::Message')
  allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
  allow(mail_double).to receive(:deliver_now).and_raise(Timeout::Error.new('Execution expired'))
  allow(CampaignMailer).to receive(:send_email).and_return(mail_double)
end

Given('ActionMailer delivery_method will change after mail creation') do
  # Mock ActionMailer to change delivery_method after mail is created
  original_delivery_method = ActionMailer::Base.delivery_method

  allow(CampaignMailer).to receive(:send_email) do |**kwargs|
    mail_double = double('Mail::Message')
    allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")

    # Change delivery method to simulate the issue
    ActionMailer::Base.delivery_method = :file

    allow(mail_double).to receive(:deliver_now) do
      # Reset it back during delivery
      ActionMailer::Base.delivery_method = :smtp
      delivered = Mail::Message.new
      delivered.to = Array(kwargs[:to]).compact
      ActionMailer::Base.deliveries << delivered
      true
    end
    mail_double
  end
end

Given('Gmail API will be disabled') do
  # Mock the service to skip Gmail API and go straight to SMTP
  original_valid_token = GmailOauthService.method(:valid_access_token) rescue nil

  # Keep oauth_configured as true, but return nil for valid_access_token
  # This forces the SMTP path
  allow(GmailOauthService).to receive(:valid_access_token).and_return(nil)

  # Mock successful SMTP delivery
  allow(CampaignMailer).to receive(:send_email) do |**kwargs|
    mail_double = double('Mail::Message')
    allow(mail_double).to receive(:encoded).and_return("Subject: Test\n\nHello")
    allow(mail_double).to receive(:deliver_now) do
      delivered = Mail::Message.new
      delivered.to = Array(kwargs[:to]).compact
      ActionMailer::Base.deliveries << delivered
      true
    end
    mail_double
  end
end

Given('GmailOauthService valid_access_token will return nil on first call and token on second') do
  call_count = 0
  allow(GmailOauthService).to receive(:valid_access_token) do
    call_count += 1
    call_count == 1 ? nil : 'smtp-oauth-token'
  end
end

Given('GmailOauthService valid_access_token will return nil for Gmail API and token for SMTP') do
  call_count = 0
  allow(GmailOauthService).to receive(:valid_access_token) do
    call_count += 1
    call_count == 1 ? nil : 'smtp-oauth-token'
  end
end

Given('GmailOauthService will return valid access token {string} for user {string}') do |token, email|
  user = User.find_by(email: email)
  allow(GmailOauthService).to receive(:valid_access_token) do |u|
    u.email == email ? token : nil
  end
end

Given('SMTP environment is configured with custom settings') do
  ENV['SMTP_ADDRESS'] = 'smtp.custom.com'
  ENV['SMTP_PORT'] = '465'
  ENV['SMTP_DOMAIN'] = 'custom.com'
  ENV['SMTP_USER_NAME'] = 'custom-user'
  ENV['SMTP_PASSWORD'] = 'custom-pass'
  ENV['SMTP_ENABLE_STARTTLS'] = 'false'
end

Given('SMTP environment is configured with custom authentication') do
  ENV['SMTP_ADDRESS'] = 'smtp.test.com'
  ENV['SMTP_PORT'] = '587'
  ENV['SMTP_DOMAIN'] = 'test.com'
  ENV['SMTP_USER_NAME'] = 'test-user'
  ENV['SMTP_PASSWORD'] = 'test-pass'
  ENV['SMTP_AUTHENTICATION'] = 'login'
  ENV['SMTP_ENABLE_STARTTLS'] = 'true'
end

Given('Rails environment is development') do
  allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
end

Given('SMTP password is not configured') do
  ENV.delete('SMTP_PASSWORD')
  ENV.delete('SMTP_ADDRESS')
end
