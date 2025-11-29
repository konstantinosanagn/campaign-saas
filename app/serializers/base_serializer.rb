##
# BaseSerializer
#
# Base class for all serializers. Provides camelCase conversion for simple JSON objects.
# This outputs plain JSON (not JSON:API format) to match frontend expectations.
#
class BaseSerializer
  ##
  # Serialize a single object to camelCase JSON
  #
  # @param object [Object] The object to serialize
  # @param options [Hash] Additional options
  # @return [Hash] Serialized object in camelCase
  def self.serialize(object, options = {})
    new(object, options).as_json
  end

  ##
  # Serialize a collection of objects to camelCase JSON array
  #
  # @param collection [Array] Collection of objects to serialize
  # @param options [Hash] Additional options
  # @return [Array] Array of serialized objects in camelCase
  def self.serialize_collection(collection, options = {})
    collection.map { |object| new(object, options).as_json }
  end

  def initialize(object, options = {})
    @object = object
    @options = options
  end

  ##
  # Convert snake_case keys to camelCase
  #
  # @param hash [Hash] Hash with snake_case keys
  # @return [Hash] Hash with camelCase keys
  def camelize_keys(hash)
    return hash unless hash.is_a?(Hash)

    hash.transform_keys { |key| camelize_key(key) }.transform_values do |value|
      case value
      when Hash
        camelize_keys(value)
      when Array
        value.map { |item| item.is_a?(Hash) ? camelize_keys(item) : item }
      else
        value
      end
    end
  end

  private

  ##
  # Convert a single key from snake_case to camelCase
  #
  # @param key [String, Symbol] The key to convert
  # @return [String] The camelCase key
  def camelize_key(key)
    key.to_s.split("_").map.with_index { |part, i| i.zero? ? part : part.capitalize }.join
  end
end
