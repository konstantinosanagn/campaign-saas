# Step definitions for ApplicationHelper feature

Given('the environment variable {string} is set to {string}') do |key, value|
  ENV[key] = value
end

Given('the user can send gmail') do
  email = ENV["DEFAULT_GMAIL_SENDER"] || "user@example.com"
  @user = User.find_by(email: email) || User.create!(
    email: email,
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Test User',
    first_name: 'Test',
    last_name: 'User',
    workspace_name: 'Test Workspace',
    job_title: 'Tester'
  )
  allow(@user).to receive(:can_send_gmail?).and_return(true)
  allow(User).to receive(:find_by).with(email: email).and_return(@user)
end

Given('the user gmail_email is {string}') do |email|
  @user ||= User.find_by(email: "user@example.com")
  allow(@user).to receive(:gmail_email).and_return(email)
end

Given('the user gmail_email is nil') do
  @user ||= User.find_by(email: "user@example.com")
  allow(@user).to receive(:gmail_email).and_return(nil)
end

Given('the user cannot send gmail') do
  @user ||= User.find_by(email: "user@example.com")
  allow(@user).to receive(:can_send_gmail?).and_return(false)
end

When('I call gmail_status_badge for the user') do
  @result = ApplicationHelper.instance_method(:gmail_status_badge).bind(self).call(@user)
end

When('I call default_gmail_sender_available?') do
  @result = ApplicationHelper.instance_method(:default_gmail_sender_available?).bind(self).call
end

When('I call default_gmail_sender_email') do
  @result = ApplicationHelper.instance_method(:default_gmail_sender_email).bind(self).call
end


Then('the application helper result should be {string}') do |expected|
  expect(@result).to eq(expected)
end

Then('the application helper result should be {bool}') do |expected|
  expect(@result).to eq(expected)
end

Given('no user exists with the default sender email') do
  User.where(email: ENV["DEFAULT_GMAIL_SENDER"]).destroy_all
end
