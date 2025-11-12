require 'rails_helper'

RSpec.describe JsonbValidator, type: :model do
  # Minimal dummy class for testing purpose
  let(:dummy_class) do
    Class.new do
      include ActiveModel::Validations
      include JsonbValidator

      def initialize(attrs = {})
        @attrs = attrs || {}
      end

      def read_attribute(name)
        @attrs[name] || @attrs[name.to_s]
      end
    end
  end

  describe '.validates_jsonb_schema' do
    it 'skips validation when the attribute is nil' do
      klass = dummy_class
      klass.validates_jsonb_schema :data, schema: { type: 'object' }

      record = klass.new(data: nil)
      expect(record).to be_valid
    end

    it 'allows empty hash and array by default' do
      klass = dummy_class
      klass.validates_jsonb_schema :data, schema: { type: 'object' }

      expect(klass.new(data: {})).to be_valid
      expect(klass.new(data: [])).to be_valid
    end

    it 'enforces strict required properties when strict and allow_empty false' do
      klass = dummy_class
      klass.validates_jsonb_schema :data, schema: { type: 'object', required: [ 'a', 'b' ] }, allow_empty: false, strict: true

      record = klass.new(data: {})
      expect(record).not_to be_valid
      expect(record.errors[:data].join).to include('missing required properties: a, b')

      record2 = klass.new(data: { 'a' => 1, 'b' => 2 })
      expect(record2).to be_valid
    end

    it 'adds error when value is not an object for object schema' do
      klass = dummy_class
      klass.validates_jsonb_schema :data, schema: { type: 'object' }

      record = klass.new(data: [ 1 ])
      expect(record).not_to be_valid
      expect(record.errors[:data]).to include('must be an object')
    end

    it 'adds error when value is not an array for array schema' do
      klass = dummy_class
      klass.validates_jsonb_schema :data, schema: { type: 'array' }

      record = klass.new(data: { 'a' => 1 })
      expect(record).not_to be_valid
      expect(record.errors[:data]).to include('must be an array')
    end

    context 'property type validations' do
      let(:schema) do
        {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer' },
            active: { type: 'boolean' },
            tags: { type: 'array' },
            meta: { type: 'object' }
          }
        }
      end

      it 'accepts values that match property types' do
        klass = dummy_class
        klass.validates_jsonb_schema :data, schema: schema

        record = klass.new(data: {
          'name' => 'Alice',
          'age' => 30,
          'active' => false,
          'tags' => [ 'a', 'b' ],
          'meta' => { 'k' => 'v' }
        })

        expect(record).to be_valid
      end

      it 'allows string integers for integer type and numeric values for string type' do
        klass = dummy_class
        klass.validates_jsonb_schema :data, schema: schema

        record = klass.new(data: {
          'name' => 123,
          'age' => '42',
          'active' => true,
          'tags' => [],
          'meta' => {}
        })

        expect(record).to be_valid
      end

      it 'adds errors for mismatched property types' do
        klass = dummy_class
        klass.validates_jsonb_schema :data, schema: schema

        record = klass.new(data: {
          'name' => nil,
          'age' => 'thirty',
          'active' => 'yes',
          'tags' => 'not_array',
          'meta' => 'not_hash'
        })

        expect(record).not_to be_valid
        expect(record.errors[:data].join).to include('age must be an integer')
        expect(record.errors[:data].join).to include('active must be a boolean')
        expect(record.errors[:data].join).to include('tags must be an array')
        expect(record.errors[:data].join).to include('meta must be an object (Hash)')
      end

      it 'adds error when a value is not string-convertible' do
        klass = dummy_class
        klass.validates_jsonb_schema :data, schema: schema

        no_stringable = Class.new do
          def respond_to?(*)
            false
          end
        end.new

        record = klass.new(data: { 'name' => no_stringable })

        expect(record).not_to be_valid
        expect(record.errors[:data].join).to include('name must be a string or convertible to string')
      end
    end
  end
end
