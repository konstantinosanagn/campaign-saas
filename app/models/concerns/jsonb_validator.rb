##
# JsonbValidator
#
# Provides JSON schema validation for JSONB fields in ActiveRecord models.
# This helps ensure data integrity for complex JSON structures stored in the database.
#
# Usage:
#   class MyModel < ApplicationRecord
#     include JsonbValidator
#
#     validates_jsonb_schema :settings, schema: {
#       type: "object",
#       properties: {
#         key: { type: "string" }
#       }
#     }
#   end
#
module JsonbValidator
  extend ActiveSupport::Concern

  class_methods do
    ##
    # Validates a JSONB attribute against a JSON schema
    # @param attribute [Symbol] The name of the JSONB attribute to validate
    # @param schema [Hash] The JSON schema definition
    # @param options [Hash] Additional validation options
    #   - allow_empty: Allow empty hash/array (default: true)
    #   - strict: Enforce strict schema validation (default: false)
    def validates_jsonb_schema(attribute, schema:, allow_empty: true, strict: false)
      validate do |record|
        value = record.read_attribute(attribute)

        # Skip validation if value is nil (handled by presence validations)
        next if value.nil?

        # Allow empty hash/array if configured
        if allow_empty && (value == {} || value == [])
          next
        end

        # Basic type checking
        schema_type = schema[:type] || schema["type"]
        if schema_type
          case schema_type
          when "object"
            unless value.is_a?(Hash)
              record.errors.add(attribute, "must be an object")
              next
            end

            # Validate required properties if specified
            if strict && schema[:required]
              missing = schema[:required] - value.keys.map(&:to_s)
              if missing.any?
                record.errors.add(attribute, "missing required properties: #{missing.join(', ')}")
              end
            end

            # Validate property types if specified
            if schema[:properties]
              schema[:properties].each do |prop_name, prop_schema|
                prop_key = prop_name.to_s
                prop_value = value[prop_key] || value[prop_key.to_sym]

                next if prop_value.nil? # Skip nil values (optional by default)

                prop_type = prop_schema[:type] || prop_schema["type"]
                if prop_type
                  case prop_type
                  when "string"
                    unless prop_value.is_a?(String)
                      record.errors.add(attribute, "#{prop_key} must be a string")
                    end
                  when "integer"
                    unless prop_value.is_a?(Integer)
                      record.errors.add(attribute, "#{prop_key} must be an integer")
                    end
                  when "boolean"
                    unless [true, false].include?(prop_value)
                      record.errors.add(attribute, "#{prop_key} must be a boolean")
                    end
                  when "array"
                    unless prop_value.is_a?(Array)
                      record.errors.add(attribute, "#{prop_key} must be an array")
                    end
                  when "object"
                    unless prop_value.is_a?(Hash)
                      record.errors.add(attribute, "#{prop_key} must be an object")
                    end
                  end
                end
              end
            end

          when "array"
            unless value.is_a?(Array)
              record.errors.add(attribute, "must be an array")
            end
          end
        end
      end
    end
  end
end

