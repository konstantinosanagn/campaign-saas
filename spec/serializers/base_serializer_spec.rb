
require 'rails_helper'

class TestCamelSerializer < BaseSerializer
  def as_json(*_args)
    camelize_keys(@object)
  end
end

RSpec.describe BaseSerializer do
  describe '.serialize' do
    it 'serializes a single object to camelCase JSON using a custom serializer' do
      object = { first_name: 'John', last_name: 'Doe' }
      result = TestCamelSerializer.serialize(object)
      expect(result).to eq({ 'firstName' => 'John', 'lastName' => 'Doe' })
    end
  end


  describe '.serialize_collection' do
    it 'serializes a collection of objects to camelCase JSON array using a custom serializer' do
      collection = [
        { first_name: 'John', last_name: 'Doe' },
        { first_name: 'Jane', last_name: 'Smith' }
      ]
      result = TestCamelSerializer.serialize_collection(collection)
      expect(result).to eq([
        { 'firstName' => 'John', 'lastName' => 'Doe' },
        { 'firstName' => 'Jane', 'lastName' => 'Smith' }
      ])
    end
  end

  describe '#camelize_keys' do
    it 'converts snake_case keys to camelCase recursively' do
      serializer = described_class.new(nil)
      hash = {
        first_name: 'John',
        address: {
          street_name: 'Main St',
          zip_code: 12345
        },
        tags: [
          { tag_name: 'foo_tag' },
          { tag_name: 'bar_tag' }
        ]
      }
      result = serializer.camelize_keys(hash)
      expect(result).to eq({
        'firstName' => 'John',
        'address' => { 'streetName' => 'Main St', 'zipCode' => 12345 },
        'tags' => [
          { 'tagName' => 'foo_tag' },
          { 'tagName' => 'bar_tag' }
        ]
      })
    end

    it 'returns non-hash input unchanged' do
      serializer = described_class.new(nil)
      expect(serializer.camelize_keys('string')).to eq('string')
    end
  end

  describe '#camelize_key' do
    it 'converts snake_case to camelCase' do
      serializer = described_class.new(nil)
      expect(serializer.send(:camelize_key, :first_name)).to eq('firstName')
      expect(serializer.send(:camelize_key, 'last_name')).to eq('lastName')
      expect(serializer.send(:camelize_key, 'simple')).to eq('simple')
    end
  end
end
