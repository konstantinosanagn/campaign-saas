# Silence noisy libvips plugin warnings in dev/test.
ENV["VIPS_WARNING"] ||= "0"

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
