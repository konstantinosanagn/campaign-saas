ParameterType(
  name: 'bool',
  regexp: /true|false|TRUE|FALSE|True|False/,
  type: TrueClass,
  transformer: ->(value) { value.downcase == 'true' }
)
