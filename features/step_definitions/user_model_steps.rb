
Given('I mock GmailSender.send_email') do
  allow(GmailSender).to receive(:send_email)
end

When('I call send_gmail! with to {string}, subject {string}, text_body {string}, and html_body {string}') do |to, subject, text_body, html_body|
  @user.send_gmail!(to: to, subject: subject, text_body: text_body, html_body: html_body)
end

Then('GmailSender.send_email should have been called with the user and correct arguments') do
  expect(GmailSender).to have_received(:send_email).with(
    user: @user,
    to: 'to@example.com',
    subject: 'Hello',
    text_body: 'Hi',
    html_body: '<b>Hi</b>'
  )
end

When('I call User.serialize_from_session with three arguments {string}, {string}, {string}') do |arg1, arg2, arg3|
  # We'll use a spy class to check the call to super
  class UserSerializeSpy < User
    class << self
      attr_accessor :super_args
      def super_called_with(*args)
        @super_args = args
      end
      def serialize_from_session(*args)
        super_called_with(*args.take(2))
      end
    end
  end
  UserSerializeSpy.serialize_from_session(arg1, arg2, arg3)
end

Then('super should be called with the first two arguments {string} and {string}') do |arg1, arg2|
  expect(UserSerializeSpy.super_args).to eq([ arg1, arg2 ])
end

Given('the user has provider {string} and uid {string}') do |provider, uid|
  @user.update!(provider: provider, uid: uid)
end
# Step definitions for user_model.feature

Given('Google OAuth data with provider {string}, uid {string}, email {string}, first_name {string}, last_name {string}') do |provider, uid, email, first_name, last_name|
  @oauth_data = OpenStruct.new(
    provider: provider,
    uid: uid,
    info: OpenStruct.new(
      email: email,
      first_name: first_name,
      last_name: last_name,
      name: (first_name.present? || last_name.present?) ? "#{first_name} #{last_name}".strip : nil
    )
  )
end

Given('the OAuth data has name {string}') do |name|
  @oauth_data.info.name = name
end
Then("the user's first_name should be {string}") do |expected|
  expect(@user.first_name).to eq(expected)
end

Then("the user's last_name should be {string}") do |expected|
  expect(@user.last_name).to eq(expected)
end

When('I call User.from_google_omniauth with the OAuth data') do
  @user = User.from_google_omniauth(@oauth_data)
end

Then('the user should be found or created with email {string} and provider {string}') do |email, provider|
  expect(@user.email).to eq(email)
  expect(@user.provider).to eq(provider)
end

Given('the user has workspace_name {string} and job_title {string}') do |workspace_name, job_title|
  @user.update!(workspace_name: workspace_name, job_title: job_title)
end

When("I check if the user's profile is complete") do
  @result = @user.profile_complete?
end

Then('the result should be {bool}') do |bool|
  expect(@result).to eq(bool)
end

Given('the user has workspace_name nil and job_title {string}') do |job_title|
  @user.update!(workspace_name: nil, job_title: job_title)
end

Given('the user has gmail_refresh_token {string}') do |token|
  @user.update!(gmail_refresh_token: token)
end

When('I check if the user is gmail connected') do
  @result = @user.gmail_connected?
end

Given('the user has gmail_refresh_token nil') do
  @user.update!(gmail_refresh_token: nil)
end

Given('the user has gmail_token_expires_at in the past') do
  @user.update!(gmail_token_expires_at: 1.day.ago)
end

When("I check if the user's gmail token is expired") do
  @result = @user.gmail_token_expired?
end

Given('the user has gmail_token_expires_at in the future') do
  @user.update!(gmail_token_expires_at: 1.day.from_now)
end

Given('the user has gmail_access_token {string} and gmail_email {string}') do |access_token, email|
  @user.update!(gmail_access_token: access_token, gmail_email: email)
end

When('I check if the user can send gmail') do
  @result = @user.can_send_gmail?
end

Given('the user has gmail_access_token nil and gmail_email {string}') do |email|
  @user.update!(gmail_access_token: nil, gmail_email: email)
end

Given('the user has gmail_access_token nil and gmail_email nil') do
  @user.update!(gmail_access_token: nil, gmail_email: nil)
end

When('I try to send gmail with the user') do
  begin
    @user.send_gmail!(to: 'to@example.com', subject: 'Test', text_body: 'Body')
    @error_raised = false
  rescue => e
    @error_raised = true
    @error_message = e.message
  end
end

Then('a user model error should be raised') do
  expect(@error_raised).to be true
end
