# Step definitions for MarkdownHelper

# Include MarkdownHelper in the test context
include MarkdownHelper

When('I convert markdown to HTML with text {string}') do |text|
  @markdown_result = markdown_to_html(text)
end

When('I convert markdown to HTML with text:') do |text|
  @markdown_result = markdown_to_html(text)
end

When('I convert markdown to HTML with text nil') do
  @markdown_result = markdown_to_html(nil)
end

When('I convert markdown to text with text {string}') do |text|
  @markdown_result = markdown_to_text(text)
end

When('I convert markdown to text with text:') do |text|
  @markdown_result = markdown_to_text(text)
end

When('I convert markdown to text with text nil') do
  @markdown_result = markdown_to_text(nil)
end

Then('the result should be {string}') do |expected|
  expect(@markdown_result).to eq(expected)
end

Then('the result should include {string}') do |text|
  expect(@markdown_result).to include(text)
end

Then('the result should not include {string}') do |text|
  expect(@markdown_result).not_to include(text)
end

Then('the result should not include more than two consecutive newlines') do
  expect(@markdown_result).not_to match(/\n\n\n+/)
end

Then('the result should be trimmed') do
  expect(@markdown_result).to eq(@markdown_result.strip)
end
