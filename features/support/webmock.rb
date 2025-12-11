# WebMock for stubbing external HTTP requests in Cucumber
require 'webmock/cucumber'
WebMock.disable_net_connect!(allow_localhost: true)
