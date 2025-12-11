Given('I am logged in as a user') do
  step 'I am logged in'
end

When('I visit the profile edit page') do
  visit complete_profile_path
end

Then('I should see the profile completion form') do
  expect(page).to have_css('#profile-completion-root')
end
