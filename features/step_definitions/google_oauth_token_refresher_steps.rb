# Ensure required ENV variables are set for all scenarios
Before do
  ENV['GOOGLE_CLIENT_ID'] = 'test-client-id'
  ENV['GOOGLE_CLIENT_SECRET'] = 'test-client-secret'
end

Given('a user with a valid Gmail refresh token') do
  @user = User.create!(
    email: "user#{rand(10000)}@example.com",
    password: 'password123',
    password_confirmation: 'password123',
    gmail_refresh_token: 'valid-refresh-token',
    gmail_access_token: 'valid-access-token',
    gmail_token_expires_at: 1.hour.from_now
  )
  @original_access_token = @user.gmail_access_token
  @original_token_expires_at = @user.gmail_token_expires_at
end

Given("the user's Gmail access token is valid and not expiring soon") do
  @user.update!(
    gmail_access_token: 'still-valid-access-token',
    gmail_token_expires_at: 1.hour.from_now
  )
  @original_access_token = @user.gmail_access_token
  @original_token_expires_at = @user.gmail_token_expires_at
end

Given("the user's Gmail access token is expired or expiring soon") do
  @user.update!(
    gmail_access_token: 'expired-access-token',
    gmail_token_expires_at: 1.minute.ago
  )
  @original_access_token = @user.gmail_access_token
  @original_token_expires_at = @user.gmail_token_expires_at
end

Given('the Google token endpoint returns a new access token') do
  stub_request(:post, GoogleOauthTokenRefresher::TOKEN_ENDPOINT)
    .to_return(
      status: 200,
      body: {
        access_token: 'new-access-token',
        expires_in: 3600
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

Given('the Google token endpoint returns an authorization error') do
  stub_request(:post, GoogleOauthTokenRefresher::TOKEN_ENDPOINT)
    .to_return(
      status: 401,
      body: { error: 'invalid_grant' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

Given('the Google token endpoint returns a non-authorization error') do
  stub_request(:post, GoogleOauthTokenRefresher::TOKEN_ENDPOINT)
    .to_return(
      status: 500,
      body: { error: 'server_error' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

When('the token refresher runs') do
  begin
    @result = GoogleOauthTokenRefresher.refresh!(@user.reload)
    @error = nil
  rescue => e
    @result = nil
    @error = e
  end
end

Then("the user's Gmail access token should not be updated") do
  expect(@user.reload.gmail_access_token).to eq(@original_access_token)
  expect(@user.reload.gmail_token_expires_at).to eq(@original_token_expires_at)
end

Then("the user's Gmail access token should be updated") do
  expect(@user.reload.gmail_access_token).to eq('new-access-token')
end

Then('the token expiry should be updated') do
  expect(@user.reload.gmail_token_expires_at).to be > @original_token_expires_at
end

Then('a Gmail authorization error should be raised') do
  expect(@error).to be_a(GmailAuthorizationError)
  expect(@error.message).to match(/revoked|invalid/i)
end

Then('a generic token refresh error should be raised') do
  expect(@error).to be_a(RuntimeError)
  expect(@error.message).to match(/token refresh failed/i)
end
