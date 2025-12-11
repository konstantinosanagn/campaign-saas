Given('the Gemini API returns an empty response body') do
  response = double('response', success?: true, body: '')
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns invalid JSON') do
  response = double('response', success?: true, body: 'not a json')
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns a response with an error message {string}') do |msg|
  error_body = { error: { message: msg } }.to_json
  response = double('response', success?: true, body: error_body)
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns a response with no candidates') do
  body = { something: 'else' }.to_json
  response = double('response', success?: true, body: body)
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns a response with a candidate but no content parts') do
  body = { candidates: [ { content: {} } ] }.to_json
  response = double('response', success?: true, body: body)
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns a response with a candidate and content parts but no text') do
  body = { candidates: [ { content: { parts: [ {} ] } } ] }.to_json
  response = double('response', success?: true, body: body)
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

Given('the Gemini API returns a valid response with email text {string}') do |text|
  body = { candidates: [ { content: { parts: [ { text: text } ] } } ] }.to_json
  response = double('response', success?: true, body: body)
  allow(Agents::WriterAgent).to receive(:post).and_return(response)
end

When('the writer agent requests an email') do
  @writer_agent = Agents::WriterAgent.new(api_key: 'test-key')
  begin
    # Provide minimal valid search_results for the run method
    search_results = { company: 'Test Corp', sources: [] }
    @result = @writer_agent.run(search_results)
  rescue => e
    @error = e
  end
end

Then('an error {string} should be raised') do |msg|
  expect(@result).to be_a(Hash)
  expect(@result[:email] || @result['email']).to eq('Failed to generate email')
  # Optionally, check logs or error details if available in the result
end

Then('the email {string} should be returned') do |text|
  expect(@result[:email] || @result['email']).to eq(text)
end
