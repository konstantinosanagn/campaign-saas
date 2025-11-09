source "https://rubygems.org"

# Core Rails
gem "rails", "~> 8.1.0"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Basic JavaScript with React support
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "webpacker", "~> 5.4"
gem "react-rails"

# Build JSON APIs
gem "jbuilder"

# Windows compatibility
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Basic caching
gem "bootsnap", require: false
gem "redis", ">= 4.0.1"
gem "image_processing", "~> 1.2"

# Tailwind CSS integration for Rails assets
gem "tailwindcss-rails"

# Authentication
gem "devise"

# Rate limiting
gem "rack-attack"

# HTTP client for API calls
gem "httparty"

# Testing
gem "factory_bot_rails", "~> 6.4"
gem "shoulda-matchers", "~> 7.0"
gem "simplecov", "~> 0.22", require: false
gem "rails-controller-testing"

group :test do
  gem "cucumber-rails", require: false
  gem "capybara"
  gem "database_cleaner-active_record"
end

group :development do
  gem "web-console"
  gem "dotenv-rails"  # Load .env file in development
end

group :development, :test do
  gem "rspec-rails", "~> 6.0"
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end