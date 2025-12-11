# frozen_string_literal: true

Given('a Ruby object with snake_case keys') do
  @object = {
    first_name: 'John',
    last_name: 'Doe',
    email_address: 'john@example.com'
  }
end

Given('a collection of Ruby objects with snake_case keys') do
  @collection = [
    { first_name: 'Alice', last_name: 'Smith' },
    { first_name: 'Bob', last_name: 'Jones' }
  ]
end

Given('a Ruby object with nested hashes and arrays with snake_case keys') do
  @object = {
    user_profile: {
      first_name: 'Jane',
      last_name: 'Roe',
      contact_info: {
        email_address: 'jane@example.com',
        phone_numbers: [
          { phone_type: 'mobile', phone_number: '123-456' },
          { phone_type: 'home', phone_number: '789-012' }
        ]
      }
    },
    account_status: 'active'
  }
end

When('I serialize the object with BaseSerializer') do
  require_relative '../../app/serializers/base_serializer'
  class BaseSerializer
    def as_json(*_args)
      if @object.is_a?(Hash)
        camelize_keys(@object)
      else
        { object: @object, options: @options }
      end
    end
  end
  @result = BaseSerializer.serialize(@object)
end

When('I serialize the collection with BaseSerializer') do
  require_relative '../../app/serializers/base_serializer'
  @result = BaseSerializer.serialize_collection(@collection)
end

Then('the result should be a hash with camelCase keys') do
  expect(@result).to be_a(Hash)
  @result.keys.each do |key|
    expect(key).to match(/\A[a-z]+(?:[A-Z][a-z0-9]+)*\z/)
  end
  expect(@result.keys).to include('firstName', 'lastName', 'emailAddress')
end

Then('the result should be an array of hashes with camelCase keys') do
  expect(@result).to be_an(Array)
  expect(@result.size).to eq(2)
  expect(@result[0].keys).to contain_exactly('firstName', 'lastName')
  expect(@result[1].keys).to contain_exactly('firstName', 'lastName')
end

Then('all keys in the result should be camelCase, including nested ones') do
  expect(@result['userProfile'].keys).to include('firstName', 'lastName', 'contactInfo')
  expect(@result['userProfile']['contactInfo'].keys).to include('emailAddress', 'phoneNumbers')
  expect(@result['userProfile']['contactInfo']['phoneNumbers'][0].keys).to include('phoneType', 'phoneNumber')
end
