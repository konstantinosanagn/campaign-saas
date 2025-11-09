Given('a user exists') do
  @user ||= User.find_by(email: 'admin@example.com') || User.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123', name: 'Admin User')
end

Given('I am logged in') do
  step 'a user exists'
  # Auth is disabled via DISABLE_AUTH; just ensure user exists
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
  replaced
end

When('I send a {word} request to {string} with JSON:') do |method, path, json|
  payload = JSON.parse(resolved_path(json))
  page.driver.browser.process(method.downcase.to_sym, resolved_path(path), payload)
  @last_response = page.driver.response
end

When('I send a {word} request to {string}') do |method, path|
  page.driver.browser.process(method.downcase.to_sym, resolved_path(path))
  @last_response = page.driver.response
end

Then('the response status should be {int}') do |code|
  expect(@last_response.status).to eq(code)
end

Then('the JSON response should include {string} with {string}') do |key, value|
  data = JSON.parse(@last_response.body)
  expect(data[key]).to eq(value)
end

Then('the JSON response should include {string}') do |key|
  data = JSON.parse(@last_response.body)
  expect(data.key?(key)).to be(true)
end

Then('the JSON array response should have at least {int} item') do |count|
  data = JSON.parse(@last_response.body)
  expect(data).to be_a(Array)
  expect(data.size).to be >= count
end

Then('the JSON nested value at {string} should equal {string}') do |path, expected|
  data = JSON.parse(@last_response.body)
  value = path.split('.').reduce(data) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil }
  expect(value.to_s).to eq(expected)
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
