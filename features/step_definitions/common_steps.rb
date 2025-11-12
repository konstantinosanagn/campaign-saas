Given('a user exists') do
  @user ||= User.find_by(email: 'admin@example.com') || User.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123', name: 'Admin User')
end

Given('I am logged in') do
  step 'a user exists'
  user = @user || User.find_by(email: 'admin@example.com')

  # If authentication is enabled, sign in the user
  unless ENV['DISABLE_AUTH'] == 'true'
    # Use Warden test helpers to sign in the user
    # This works with Rack::Test driver
    login_as(user, scope: :user)
  end
end

When('I visit the home page') do
  visit '/'
end

Then('I should see the dashboard container') do
  expect(page).to have_css('#campaign-dashboard-root')
end

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

When('I send a {word} request to {string} with JSON:') do |method, path, json|
  payload_str = resolved_path(json)
  path_resolved = resolved_path(path)

  # Evaluate Ruby expressions in JSON string (e.g., "A" * 255)
  # This is safe because it only evaluates in the test environment
  payload_str = payload_str.gsub(/"([^"]*)"\s*\*\s*(\d+)/) do |match|
    str = $1
    count = $2.to_i
    '"' + (str * count) + '"'
  end

  # Parse JSON to hash for Rails to process (for GET/POST which can use params)
  payload_hash = JSON.parse(payload_str)

  case method.downcase
  when 'get'
    headers = { 'Accept' => 'application/json' }
    page.driver.get(path_resolved, payload_hash, headers)
  when 'post'
    headers = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
    # For POST, send as JSON string to ensure proper handling
    page.driver.browser.post(
      path_resolved,
      payload_str,
      { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
    )
  when 'patch', 'put'
    # For PATCH/PUT, use Rack::Test::Session directly to send JSON body
    browser = page.driver.browser
    # Rack::Test::Session supports patch/put with input for body
    if browser.respond_to?(method.downcase)
      browser.send(
        method.downcase,
        path_resolved,
        payload_str,
        { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      )
    else
      # Fallback: use custom_request
      env = Rack::MockRequest.env_for(
        path_resolved,
        method: method.upcase,
        input: payload_str,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_ACCEPT' => 'application/json'
      )
      browser.custom_request(method.upcase, path_resolved, env)
    end
  when 'delete'
    headers = { 'Accept' => 'application/json' }
    page.driver.delete(path_resolved, payload_hash, headers)
  else
    raise "Unsupported HTTP method: #{method}"
  end

  @last_response = page.driver.response
end

When('I send a {word} request to {string}') do |method, path|
  path_resolved = resolved_path(path)
  headers = { 'Accept' => 'application/json' }

  case method.downcase
  when 'get'
    page.driver.get(path_resolved, {}, headers)
  when 'delete'
    page.driver.delete(path_resolved, {}, headers)
  else
    page.driver.browser.process(method.downcase.to_sym, path_resolved)
  end

  @last_response = page.driver.response
end

Then('the response status should be {int}') do |code|
  if @last_response.status != code
    # Print response body for debugging
    puts "\n=== Response Debug ==="
    puts "Expected: #{code}, Got: #{@last_response.status}"
    puts "Response body: #{@last_response.body}"
    puts "=====================\n"
  end
  expect(@last_response.status).to eq(code)
end

Then('the JSON response should include {string} with {string}') do |key, value|
  data = JSON.parse(@last_response.body)
  # Handle both string keys and symbol keys, and nested structures
  if data.is_a?(Hash)
    # Try string key first, then symbol key
    actual_value = data[key] || data[key.to_sym] || data[key.to_s.camelize(:lower).to_sym]
    expect(actual_value.to_s).to eq(value)
  else
    expect(data[key]).to eq(value)
  end
end

Then('the JSON response should include {string}') do |key|
  data = JSON.parse(@last_response.body)
  # Handle both hash and array responses
  if data.is_a?(Hash)
    expect(data.key?(key) || data.key?(key.to_sym) || data.key?(key.to_s.camelize(:lower).to_sym)).to be(true)
  else
    expect(data).to respond_to(:include?)
  end
end

Then('the JSON array response should have at least {int} item') do |count|
  data = JSON.parse(@last_response.body)
  expect(data).to be_a(Array)
  expect(data.size).to be >= count
end

Then('the JSON nested value at {string} should equal {string}') do |path, expected|
  data = JSON.parse(@last_response.body)
  value = path.split('.').reduce(data) do |acc, key|
    if acc.is_a?(Hash)
      acc[key] || acc[key.to_sym] || acc[key.to_s.camelize(:lower).to_sym]
    else
      nil
    end
  end
  # Handle newline characters - convert \n to actual newlines for comparison
  expected_normalized = expected.gsub('\\n', "\n")
  expect(value.to_s).to eq(expected_normalized)
end

Then('the page title should include {string}') do |text|
  expect(page.title).to include(text)
end

Then('I should see a meta tag {string}') do |name|
  expect(page).to have_css("meta[name='#{name}']", visible: false)
end

Then('I should see a link icon of type {string}') do |type|
  expect(page).to have_css("link[rel='icon'][type='#{type}']", visible: false)
end

Then('I should see the stylesheet pack tag') do
  expect(page.body).to include('/packs/application.css')
end

Then('I should see the javascript pack tag') do
  expect(page.body).to include('/packs/application.js')
end

Then('the dashboard root should have CSS class {string}') do |klass|
  expect(page).to have_css("#campaign-dashboard-root.#{klass}")
end
