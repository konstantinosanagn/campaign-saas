# Helper module for authentication in tests
# Use Warden's login_as for request specs

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  
  config.before(:each, type: :request) do
    Warden.test_mode!
  end
  
  config.after(:each, type: :request) do
    Warden.test_reset!
  end
end

# Override sign_in for request specs to use login_as
module AuthenticationHelpers
  def sign_in(user)
    login_as(user, scope: :user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end







