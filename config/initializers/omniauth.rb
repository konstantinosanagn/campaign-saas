# config/initializers/omniauth.rb

# OmniAuth 2.x defaults to POST only, but we're explicit:
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
