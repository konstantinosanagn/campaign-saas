# SimpleCov is loaded in simplecov_setup.rb (loaded before this file)
# Load it explicitly if COVERAGE is set but simplecov_setup wasn't loaded
if ENV['COVERAGE'] && !defined?(SimpleCov)
  require_relative 'simplecov_setup'
end

require 'cucumber/rails'
require 'rspec/mocks'
require 'warden/test/helpers'
require 'active_job/test_helper'

World(RSpec::Mocks::ExampleMethods)
World(Warden::Test::Helpers)
World(ActiveJob::TestHelper)

Before do
  RSpec::Mocks.setup
  # Default to disabled auth for most tests
  ENV['DISABLE_AUTH'] = 'true'
  # Clear any existing Warden sessions
  Warden.test_mode!
  # Clear email deliveries before each scenario
  ActionMailer::Base.deliveries.clear
  # Use test adapter for ActiveJob
  ActiveJob::Base.queue_adapter = :test
  # Clear enqueued jobs before each scenario
  ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  ActiveJob::Base.queue_adapter.performed_jobs.clear
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
