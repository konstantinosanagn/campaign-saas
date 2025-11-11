# SimpleCov is loaded in simplecov_setup.rb (loaded before this file)
# Load it explicitly if COVERAGE is set but simplecov_setup wasn't loaded
if ENV['COVERAGE'] && !defined?(SimpleCov)
  require_relative 'simplecov_setup'
end

require 'cucumber/rails'
require 'rspec/mocks'
require 'warden/test/helpers'

World(RSpec::Mocks::ExampleMethods)
World(Warden::Test::Helpers)

Before do
  RSpec::Mocks.setup
  # Default to disabled auth for most tests
  ENV['DISABLE_AUTH'] = 'true'
  # Clear any existing Warden sessions
  Warden.test_mode!
end

After do
  RSpec::Mocks.verify
  RSpec::Mocks.teardown
  # Reset DISABLE_AUTH after each scenario
  ENV['DISABLE_AUTH'] = 'true'
  # Clear Warden sessions after each scenario
  Warden.test_reset!
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :rack_test

# Use transactional fixtures for speed and isolation
begin
  DatabaseCleaner.strategy = :transaction
  Cucumber::Rails::Database.javascript_strategy = :truncation
rescue NameError
  raise "You need to add database_cleaner-active_record to your Gemfile (in the :test group)"
end
