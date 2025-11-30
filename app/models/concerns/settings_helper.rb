##
# SettingsHelper
#
# Provides a consistent way to access hash settings that may have string or symbol keys.
# This eliminates the need for the verbose pattern: settings["key"] || settings[:key]
#
# Usage:
#   include SettingsHelper
#   value = get_setting(settings, :tone)
#   value = get_setting(settings, "tone")
#
# Works with nested hashes too:
#   value = dig_setting(hash, :brand_voice, :tone)
#
module SettingsHelper
  extend ActiveSupport::Concern

  ##
  # Gets a setting value from a hash, checking both string and symbol keys
  # @param hash [Hash] The hash to search in
  # @param key [String, Symbol] The key to look up (can be string or symbol)
  # @return [Object, nil] The value if found, nil otherwise
  def get_setting(hash, key)
    return nil if hash.nil? || !hash.is_a?(Hash)

    key_s = key.to_s
    key_sym = key.to_sym

    hash[key_s] || hash[key_sym]
  end

  ##
  # Similar to Hash#dig but checks both string and symbol keys at each level
  # @param hash [Hash] The hash to search in
  # @param keys [Array<String, Symbol>] The keys to dig through
  # @return [Object, nil] The value if found, nil otherwise
  def dig_setting(hash, *keys)
    return nil if hash.nil? || !hash.is_a?(Hash)
    return hash if keys.empty?

    current = hash
    keys.each do |key|
      current = get_setting(current, key)
      return nil if current.nil? || (!current.is_a?(Hash) && key != keys.last)
    end

    current
  end

  ##
  # Gets a setting value with a default fallback
  # @param hash [Hash] The hash to search in
  # @param key [String, Symbol] The key to look up
  # @param default [Object] The default value to return if key not found
  # @return [Object] The value if found, default otherwise
  def get_setting_with_default(hash, key, default = nil)
    value = get_setting(hash, key)
    value.nil? ? default : value
  end

  ##
  # Gets multiple settings at once, returning a hash
  # @param hash [Hash] The hash to search in
  # @param keys [Array<String, Symbol>] The keys to extract
  # @return [Hash] Hash with requested keys and their values
  def get_settings(hash, *keys)
    result = {}
    keys.each do |key|
      value = get_setting(hash, key)
      result[key.to_sym] = value unless value.nil?
    end
    result
  end

  ##
  # Checks if a setting exists (has a non-nil value)
  # @param hash [Hash] The hash to search in
  # @param key [String, Symbol] The key to check
  # @return [Boolean] True if the key exists and has a value
  def setting_present?(hash, key)
    value = get_setting(hash, key)
    !value.nil? && value != ""
  end

  ##
  # Module-level methods for use without including the module
  # These can be called as SettingsHelper.get_setting(hash, key)
  # Using module_function makes methods available both as instance methods (when included)
  # and as module-level methods (when called directly)
  module_function :get_setting, :dig_setting, :get_setting_with_default

  module ClassMethods
    def get_setting(hash, key)
      return nil if hash.nil? || !hash.is_a?(Hash)

      key_s = key.to_s
      key_sym = key.to_sym

      hash[key_s] || hash[key_sym]
    end

    def dig_setting(hash, *keys)
      return nil if hash.nil? || !hash.is_a?(Hash)
      return hash if keys.empty?

      current = hash
      keys.each do |key|
        current = get_setting(current, key)
        return nil if current.nil? || (!current.is_a?(Hash) && key != keys.last)
      end

      current
    end

    def get_setting_with_default(hash, key, default = nil)
      value = get_setting(hash, key)
      value.nil? ? default : value
    end
  end
end
