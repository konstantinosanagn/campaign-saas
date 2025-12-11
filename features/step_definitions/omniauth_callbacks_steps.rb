# This step is a no-op for API/controller-based tests
Given('I am on the sign in page') do
  # no-op
end
When('I sign in with Google successfully and my profile is complete') do
  mock_omniauth(:google_oauth2, profile_complete: true)
  visit user_google_oauth2_omniauth_callback_path
end

When('I sign in with Google successfully and my profile is incomplete') do
  mock_omniauth(:google_oauth2, profile_complete: false)
  visit user_google_oauth2_omniauth_callback_path
end

When('I fail to sign in with Google') do
  mock_omniauth_failure(:google_oauth2)
  visit user_google_oauth2_omniauth_callback_path
end

When('the omniauth authentication fails') do
  visit user_google_oauth2_omniauth_callback_path(error: 'access_denied')
end

Then('I should be signed in') do
  # Use the actual expected redirect paths as strings
  expected_paths = [
    '/',
    '/dashboard',
    complete_profile_path
  ]
  expect(expected_paths).to include(current_path)
end

Then('I should be redirected to the dashboard') do
  expect([ '/dashboard', '/' ]).to include(current_path)
end

Then('I should be redirected to the complete profile page') do
  expect(current_path).to eq(complete_profile_path)
end

Then('I should see an authentication error message') do
  # The error is set as a flash alert and passed to the React component as flashAlert
  # The controller may redirect to sign up with one message or to sign in with another
  possible_errors = [
    'There was a problem signing you in through Google',
    'Authentication failed. Please try again.'
  ]
  found = possible_errors.any? { |msg| page.body.include?(msg) }
  expect(found).to be true
end

Then('I should be redirected to the sign up page') do
  expect(current_path).to eq(new_user_registration_path)
end

Then('I should see a generic authentication failed message') do
  # The error is set as a flash alert and passed to the React component as flashAlert
  react_props_match = page.body.match(/data-react-props='([^']+)'/)
  react_props_match ||= page.body.match(/data-react-props="([^"]+)"/)
  if react_props_match
    props_json = react_props_match[1]
    require 'cgi'
    props_json = CGI.unescapeHTML(props_json)
    begin
      props = JSON.parse(props_json)
      expect(props['flashAlert']).to eq('Authentication failed. Please try again.')
    rescue JSON::ParserError
      raise "Could not parse React props JSON: #{props_json}"
    end
  else
    raise 'Could not find data-react-props attribute in page body'
  end
end

Then('I should be redirected to the sign in page') do
  expect(current_path).to eq(new_user_session_path)
end

# Helper methods for mocking
def mock_omniauth(provider, profile_complete:)
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new({
    provider: provider.to_s,
    uid: '123545',
    info: {
      email: 'user@example.com',
      name: 'Test User'
    },
    credentials: {
      token: 'mock_token',
      refresh_token: 'mock_refresh_token',
      expires_at: 1.hour.from_now.to_i
    }
  })
  allow_any_instance_of(User).to receive(:profile_complete?).and_return(profile_complete)
end

def mock_omniauth_failure(provider)
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[provider] = :invalid_credentials
end
