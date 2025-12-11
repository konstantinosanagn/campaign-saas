Then('SettingsHelper.get_setting with :tone returns {string}') do |expected|
  expect(SettingsHelper.get_setting(@settings, :tone)).to eq(expected)
end

Then('SettingsHelper.get_setting with "tone" returns {string}') do |expected|
  expect(SettingsHelper.get_setting(@settings, 'tone')).to eq(expected)
end

Then('SettingsHelper.dig_setting with :brand_voice, :tone returns {string}') do |expected|
  expect(SettingsHelper.dig_setting(@settings, :brand_voice, :tone)).to eq(expected)
end

Then('SettingsHelper.dig_setting with "brand_voice", "tone" returns {string}') do |expected|
  expect(SettingsHelper.dig_setting(@settings, 'brand_voice', 'tone')).to eq(expected)
end

Then('SettingsHelper.get_setting_with_default with :missing and default {string} returns {string}') do |default, expected|
  expect(SettingsHelper.get_setting_with_default(@settings, :missing, default)).to eq(expected)
end
Given('a settings hash with {string} set to nil') do |key|
  @settings = { key => nil }
end
Given('a nil settings hash') do
  @settings = nil
end

Given('a non-Hash settings object') do
  @settings = 42
end

Then('get_setting with :any returns nil') do
  expect(get_setting(@settings, :any)).to be_nil
end

Then('dig_setting with :any returns nil') do
  expect(dig_setting(@settings, :any)).to be_nil
end

Then('dig_setting with no keys returns the original hash') do
  expect(dig_setting(@settings)).to eq(@settings)
end

Then('get_setting_with_default with :foo and default {string} returns {string}') do |default, expected|
  expect(get_setting_with_default(@settings, :foo, default)).to eq(expected)
end

Then('get_setting_with_default with :bar and default {string} returns {string}') do |default, expected|
  expect(get_setting_with_default(@settings, :bar, default)).to eq(expected)
end
ParameterType(
  name: 'symbol',
  regexp: /:[a-zA-Z_][a-zA-Z0-9_]*/,
  type: Symbol,
  transformer: ->(s) { s[1..-1].to_sym }
)

require 'rspec/expectations'
require_relative '../../app/models/concerns/settings_helper'

World(SettingsHelper)

Given('a settings hash with {string} set to {string}') do |key, value|
  @settings = { key => value }
end

Given('a settings hash with no {string} key') do |key|
  @settings = {}
end

Given('a settings hash with {string} set to {int} and {symbol} set to {int}') do |key1, val1, key2, val2|
  @settings = { key1 => val1, key2 => val2 }
end

Given('a settings hash with {string} set to {string} and {string} set to {string}') do |key1, val1, key2, val2|
  @settings = { key1 => val1, key2 => val2 }
end

Given('a nested settings hash with brand_voice.tone set to {string}') do |value|
  @settings = { 'brand_voice' => { 'tone' => value } }
end

Then('get_setting with :tone returns {string}') do |expected|
  expect(get_setting(@settings, :tone)).to eq(expected)
end

Then('get_setting with "tone" returns {string}') do |expected|
  expect(get_setting(@settings, 'tone')).to eq(expected)
end

Then('dig_setting with :brand_voice, :tone returns {string}') do |expected|
  expect(dig_setting(@settings, :brand_voice, :tone)).to eq(expected)
end

Then('dig_setting with "brand_voice", "tone" returns {string}') do |expected|
  expect(dig_setting(@settings, 'brand_voice', 'tone')).to eq(expected)
end

Then('get_setting_with_default with :missing and default {string} returns {string}') do |default, expected|
  expect(get_setting_with_default(@settings, :missing, default)).to eq(expected)
end

Then('get_settings with :a, :b returns a hash with a: {int} and b: {int}') do |a_val, b_val|
  result = get_settings(@settings, :a, :b)
  expect(result).to eq({ a: a_val, b: b_val })
end


Then('setting_present? with :present returns true') do
  expect(setting_present?(@settings, :present)).to be true
end

Then('setting_present? with :empty returns false') do
  expect(setting_present?(@settings, :empty)).to be false
end

Then('setting_present? with :missing returns false') do
  expect(setting_present?(@settings, :missing)).to be false
end
