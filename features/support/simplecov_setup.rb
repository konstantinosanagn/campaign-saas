# SimpleCov setup - must be loaded BEFORE any application code
# This file is loaded before env.rb to ensure coverage tracking starts early

if ENV['COVERAGE']
  require 'simplecov'
  
  SimpleCov.start 'rails' do
    # Filter out test files, migrations, and configuration
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/vendor/'
    add_filter '/config/'
    add_filter '/db/'
    add_filter '/bin/'
    add_filter '/node_modules/'
    add_filter '/tmp/'
    add_filter '/coverage/'
    
    # Track these directories
    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Services', 'app/services'
    add_group 'Mailers', 'app/mailers'
    add_group 'Helpers', 'app/helpers'
    add_group 'Jobs', 'app/jobs'
    add_group 'Libraries', 'app/lib'
    
    # Minimum coverage threshold (optional - can be adjusted)
    # Set to 0 to not fail on low coverage, or adjust based on your needs
    minimum_coverage 0  # Disabled for now - can be enabled after improving coverage
  end
  
  puts "SimpleCov started - Coverage tracking enabled"
end

