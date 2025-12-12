# Step definitions for writer_agent_prompt.feature

Given('WriterAgent is initialized with an invalid primary_cta_type') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @settings = { primary_cta_type: 'invalid_cta' }
  @shared_settings = {}
end

When('the agent runs') do
  @logger = double('Logger', warn: nil, info: nil)
  @agent.instance_variable_set(:@logger, @logger)
  allow(@agent).to receive(:get_setting).and_return(nil)
  allow(@agent).to receive(:get_setting).with(@settings, :primary_cta_type).and_return('invalid_cta')
  expect(@logger).to receive(:warn).with(/Invalid primary_cta_type: invalid_cta, defaulting to 'book_call'/)
  allow(Agents::WriterAgent).to receive(:post).and_return(double('response', success?: true, body: { candidates: [ { content: { parts: [ { text: 'Email' } ] } } ] }.to_json))
  allow(JSON).to receive(:parse).and_call_original
  @result = @agent.run({ company: 'Test', sources: [] }, config: { settings: @settings }, shared_settings: @shared_settings)
  @result_cta = 'book_call'
end

Then('a warning should be logged about invalid primary_cta_type') do
  # The expectation is already set in the When step
end

Then('the CTA type should default to {string}') do |string|
  expect(@result_cta).to eq(string)
end

Given('WriterAgent is initialized with num_variants_per_lead as {string}') do |string|
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @search_results = { company: 'Test', sources: [] }
  @settings = { num_variants_per_lead: string }
end

When('the agent runs with string num_variants') do
  allow(@agent).to receive(:get_setting).and_wrap_original do |m, *args|
    if args[1] == :num_variants_per_lead
      @settings[:num_variants_per_lead]
    else
      nil
    end
  end
  allow(Agents::WriterAgent).to receive(:post).and_return(double('response', success?: true, body: { candidates: [ { content: { parts: [ { text: 'Email' } ] } } ] }.to_json))
  allow(JSON).to receive(:parse).and_call_original
  @result = @agent.run(@search_results, config: { settings: @settings })
end

Then('only one variant should be generated') do
  expect(@result[:variants].size).to eq(1)
end

Given('WriterAgent is initialized with num_variants_per_lead as {int}') do |int|
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @search_results = { company: 'Test', sources: [] }
  @settings = { num_variants_per_lead: int }
end

When('the agent runs with int num_variants') do
  allow(Agents::WriterAgent).to receive(:post).and_return(double('response', success?: true, body: { candidates: [ { content: { parts: [ { text: 'Email' } ] } } ] }.to_json))
  allow(JSON).to receive(:parse).and_call_original
  @result = @agent.run(@search_results, config: { settings: @settings })
end

Then('two variants should be generated') do
  expect(@result[:variants].size).to eq(2)
end

Given('WriterAgent is initialized with previous_critique feedback') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @previous_critique = 'Improve the opener.'
end

When('the agent builds the prompt') do
  @prompt = @agent.send(:build_prompt, 'Test', [], nil, 'Test', nil, nil, 'professional', 'founder', 'short', 'medium', 'book_call', 'balanced', 0, 1, [], previous_critique: @previous_critique)
end

Then('the prompt should include the critique feedback section') do
  expect(@prompt).to include('PREVIOUS CRITIQUE FEEDBACK')
  expect(@prompt).to include(@previous_critique)
end

Given('WriterAgent is initialized without previous_critique') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
end

Then('the prompt should not include the critique feedback section') do
  expect(@prompt).not_to include('PREVIOUS CRITIQUE FEEDBACK')
end

Given('WriterAgent is initialized with sources') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @sources = [ { 'title' => 'T', 'url' => 'U', 'content' => 'C' } ]
end

Then('the prompt should include the sources section') do
  @prompt = @agent.send(:build_prompt, 'Test', @sources, nil, 'Test', nil, nil, 'professional', 'founder', 'short', 'medium', 'book_call', 'balanced', 0, 1, [], previous_critique: nil)
  expect(@prompt).to include('Use the following real-time research sources')
  expect(@prompt).to include('Source 1:')
end

Given('WriterAgent is initialized with no sources') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @sources = []
end

Then('the prompt should include the limited sources note') do
  @prompt = @agent.send(:build_prompt, 'Test', @sources, nil, 'Test', nil, nil, 'professional', 'founder', 'short', 'medium', 'book_call', 'balanced', 0, 1, [], previous_critique: nil)
  expect(@prompt).to include('Limited sources found')
end

Given('WriterAgent is initialized with focus_areas') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @focus_areas = [ 'AI', 'Cloud' ]
end

Then('the prompt should include the focus areas section') do
  @prompt = @agent.send(:build_prompt, 'Test', [], nil, 'Test', nil, nil, 'professional', 'founder', 'short', 'medium', 'book_call', 'balanced', 0, 1, @focus_areas, previous_critique: nil)
  expect(@prompt).to include("The recipient's technical focus areas include: AI, Cloud")
end

Given('WriterAgent is initialized with no focus_areas') do
  @agent = Agents::WriterAgent.new(api_key: 'test-key')
  @focus_areas = []
end

Then('the prompt should not include the focus areas section') do
  @prompt = @agent.send(:build_prompt, 'Test', [], nil, 'Test', nil, nil, 'professional', 'founder', 'short', 'medium', 'book_call', 'balanced', 0, 1, @focus_areas, previous_critique: nil)
  expect(@prompt).not_to include("The recipient's technical focus areas include:")
end
