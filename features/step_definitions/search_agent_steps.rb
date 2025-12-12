# features/step_definitions/search_agent_steps.rb

require 'rspec/mocks'
require 'logger'

Given('the Tavily API responds without a {string} field') do |field|
  @mock_response = double('response', success?: true, parsed_response: {})
  allow(Agents::SearchAgent).to receive(:post).and_return(@mock_response)
end

Given('the Tavily API responds with a valid {string} array') do |field|
  @mock_results = [ { 'title' => 'Test', 'url' => 'http://example.com', 'content' => 'Example content' } ]
  @mock_response = double('response', success?: true, parsed_response: { field => @mock_results })
  allow(Agents::SearchAgent).to receive(:post).and_return(@mock_response)
end

Given('the Tavily API responds with invalid data') do
  @mock_response = double('response', success?: true, parsed_response: nil)
  allow(Agents::SearchAgent).to receive(:post).and_return(@mock_response)
end

Given('parsing the response raises an exception') do
  # We'll simulate this in the When step by stubbing map to raise
  @raise_on_map = true
end

When('the search agent performs a search') do
  @logger = double('logger').as_null_object
  @agent = Agents::SearchAgent.new(tavily_key: 'test', gemini_key: 'test')
  @agent.instance_variable_set(:@logger, @logger)
  if @raise_on_map
    allow(@mock_response).to receive(:parsed_response).and_raise(StandardError.new('parse error'))
    allow(Agents::SearchAgent).to receive(:post).and_return(@mock_response)
  end
  @result = @agent.send(:run_tavily_search, 'query')
end

Then('a warning should be logged about missing results') do
  expect(@logger).to have_received(:warn).with(/no 'results' field/i)
end

Then('an empty array should be returned') do
  expect(@result).to eq([])
end

Then('the results should be mapped and returned') do
  expect(@result).to eq(@mock_results.map { |r| { title: r['title'], url: r['url'], content: r['content'] } })
end

Then('an error should be logged about the failure') do
  expect(@logger).to have_received(:error).with(/Tavily batch search failed:/)
end
