# Step definitions specifically for user registration and sessions testing

# Helper method to resolve path (from common_steps.rb)
def resolved_path(path)
  replaced = path
  replaced = replaced.gsub('#{@campaign.id}', (@campaign&.id || '').to_s)
  replaced = replaced.gsub('\#{@campaign.id}', (@campaign&.id || '').to_s)
  replaced = replaced.gsub('#{@lead.id}', (@lead&.id || '').to_s)
  replaced = replaced.gsub('\#{@lead.id}', (@lead&.id || '').to_s)
  replaced = replaced.gsub('#{@other_campaign.id}', (@other_campaign&.id || '').to_s)
  replaced = replaced.gsub('\#{@other_campaign.id}', (@other_campaign&.id || '').to_s)
  replaced = replaced.gsub('#{@other_lead.id}', (@other_lead&.id || '').to_s)
  replaced = replaced.gsub('\#{@other_lead.id}', (@other_lead&.id || '').to_s)
  replaced = replaced.gsub('#{@agent_config.id}', (@agent_config&.id || '').to_s)
  replaced = replaced.gsub('\#{@agent_config.id}', (@agent_config&.id || '').to_s)
  replaced
end

When('I send a POST request to {string} with params:') do |path, params_json|
  path_resolved = resolved_path(path)
  params = JSON.parse(params_json)

  # Convert nested JSON structure to flat params for form submission
  # e.g., {"user": {"email": "x"}, "first_name": "y"} -> {"user[email]": "x", "first_name": "y"}
  flat_params = {}
  params.each do |key, value|
    if value.is_a?(Hash)
      value.each do |nested_key, nested_value|
        flat_params["#{key}[#{nested_key}]"] = nested_value
      end
    else
      flat_params[key] = value
    end
  end

  # Ensure authenticity_token is included to satisfy CSRF protection.
  unless flat_params.key?('authenticity_token')
    page.driver.get(path_resolved)
    response_body = page.driver.response&.body.to_s
    authenticity_token = response_body[/name="authenticity_token" value="([^"]+)"/, 1]
    flat_params['authenticity_token'] = authenticity_token if authenticity_token
  end

  # Send POST request with form data (application/x-www-form-urlencoded)
  page.driver.browser.post(
    path_resolved,
    flat_params,
    { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }
  )

  @last_response = page.driver.response
end

Then('a user should exist with email {string}') do |email|
  user = User.find_by(email: email)
  expect(user).to be_present
  @user = user
end

Then('no user should exist with email {string}') do |email|
  user = User.find_by(email: email)
  expect(user).to be_nil
end

Then('only one user should exist with email {string}') do |email|
  users = User.where(email: email)
  expect(users.count).to eq(1)
end

Given('the application is configured to require account confirmation') do
  # For now, we'll skip this as Devise confirmation is not enabled
  # This step is a placeholder for future functionality
  skip "Account confirmation is not currently enabled"
end
