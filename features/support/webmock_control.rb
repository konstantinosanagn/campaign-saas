Before do
  WebMock.disable!
end

Before('@webmock_enabled') do
  # Certain .feature requires WebMock to be enabled, while some do not
  # Tag the .feature with @webmock_enabled to enable WebMock for that specific feature during test
  WebMock.enable!
end

After('@webmock_enabled') do
  WebMock.disable!
end
