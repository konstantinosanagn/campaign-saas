When('I extract score from critique text {string} with default {int}') do |critique, default|
  critique = nil if critique == 'nil'
  @score_result = @agent.send(:extract_score_from_critique, critique, default)
end

When('I extract score from critique text nil with default {int}') do |default|
  critique = nil
  @score_result = @agent.send(:extract_score_from_critique, critique, default)
end

Then('the extracted score should be {int}') do |expected|
  expect(@score_result).to eq(expected)
end
Given('I have a CritiqueAgent instance that raises an error on critique') do
  @agent = Agents::CritiqueAgent.new(api_key: 'dummy', model: 'test-model')
  allow(@agent.class).to receive(:post).and_raise(StandardError.new('API error'))
end

When('I run critique with email content {string}') do |content|
  @critique_result = @agent.send(:critique, { 'email_content' => content })
end

Then('the critique result should have network error details') do
  expect(@critique_result).to include('critique' => nil)
  expect(@critique_result).to include('error' => 'Network error')
  expect(@critique_result['detail']).to include('API error')
end
# frozen_string_literal: true

Given('I have a CritiqueAgent instance') do
  @agent = Agents::CritiqueAgent.new(api_key: 'dummy', model: 'test-model')
end

When('I extract feedback text from nil') do
  @result = @agent.send(:extract_feedback_text, nil)
end

When('I extract feedback text from an empty string') do
  @result = @agent.send(:extract_feedback_text, '')
end

When('I extract feedback text from:') do |string|
  @result = @agent.send(:extract_feedback_text, string)
end

Then('the result should be an empty string') do
  expect(@result).to eq('')
end

Then('the result should be:') do |string|
  expect(@result).to eq(string.strip)
end

When(/^I check should_rewrite\? with policy "([^"]+)", meets_min_score (true|false), and (.+)$/) do |policy, meets_min, critique_text|
  critique_text = '' if critique_text == 'blank critique_text'
  critique_text = nil if critique_text == 'nil critique_text'
  meets_min_score = meets_min == 'true'
  @result = @agent.send(:should_rewrite?, policy, meets_min_score, critique_text)
end

Then('the should_rewrite? result should be {word}') do |expected|
  expect(@result.to_s).to eq(expected)
end


When('I rewrite email with content {string}, critique_text {string}, and settings {string}') do |content, critique, settings|
  @log_output = StringIO.new
  allow(@agent).to receive(:log) { |msg| @log_output.puts(msg) }
  unless defined?(@post_stubbed) && @post_stubbed
    allow(@agent.class).to receive(:post).and_return(double(parsed_response: { 'candidates' => [ { 'content' => { 'parts' => [ { 'text' => 'Rewritten email text' } ] } } ] }))
    @post_stubbed = true
  end
  @result = @agent.send(:rewrite_email, content, critique, JSON.parse(settings))
end

Then('the rewrite_email result should be {string}') do |expected|
  expect(@result).to eq(expected)
end

And('the log should include {string}') do |msg|
  expect(@log_output.string).to include(msg)
end

Given('I have a CritiqueAgent instance with a stubbed API response {string}') do |response|
  @agent = Agents::CritiqueAgent.new(api_key: 'dummy', model: 'test-model')
  allow(@agent.class).to receive(:post).and_return(double(parsed_response: { 'candidates' => [ { 'content' => { 'parts' => [ { 'text' => response } ] } } ] }))
  @log_output = StringIO.new
  allow(@agent).to receive(:log) { |msg| @log_output.puts(msg) }
end

Given('I have a CritiqueAgent instance that raises an error on API call') do
  @agent = Agents::CritiqueAgent.new(api_key: 'dummy', model: 'test-model')
  allow(@agent.class).to receive(:post).and_raise(StandardError.new('API error'))
  @post_stubbed = true
  @log_output = StringIO.new
  allow(@agent).to receive(:log) { |msg| @log_output.puts(msg) }
end

Then('the rewrite_email result should be nil') do
  expect(@result).to be_nil
end

Given('Rails logger is available') do
  stub_const('Rails', Class.new)
  logger = double('Logger')
  allow(logger).to receive(:info)
  allow(Rails).to receive(:respond_to?).with(:logger).and_return(true)
  allow(Rails).to receive(:logger).and_return(logger)
  @rails_logger = logger
end

When('I log the message {string}') do |msg|
  @agent ||= Agents::CritiqueAgent.new(api_key: 'dummy', model: 'test-model')
  @agent.send(:log, msg)
end

Then('Rails.logger should receive info with {string}') do |msg|
  expect(@rails_logger).to have_received(:info).with(msg)
end

Given('Rails logger is not available') do
  hide_const('Rails')
  @stdout = StringIO.new
  allow($stdout).to receive(:puts) { |msg| @stdout.puts(msg) }
end

Then('stdout should include {string}') do |msg|
  expect(@stdout.string).to include(msg)
end
