require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'   # don’t include your test files
  add_filter '/vendor/'
  enable_coverage :branch
end
puts "SimpleCov started — coverage results will be saved to coverage/index.html"

require 'rspec'
require 'webmock/rspec'

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

# Load services for testing
require_relative '../app/services/search_agent'
require_relative '../app/services/writer_agent'
require_relative '../app/services/critique_agent'
require_relative '../app/services/orchestrator'
