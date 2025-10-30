require 'cucumber/rails'

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :rack_test

# Use transactional fixtures for speed and isolation
begin
  DatabaseCleaner.strategy = :transaction
  Cucumber::Rails::Database.javascript_strategy = :truncation
rescue NameError
  raise "You need to add database_cleaner-active_record to your Gemfile (in the :test group)"
end

Before do
  ENV['DISABLE_AUTH'] = 'true'
end


