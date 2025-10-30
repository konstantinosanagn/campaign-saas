#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'app/services/orchestrator'

# Main entry point
if ARGV.empty?
  puts "Usage: ruby main.rb <company_name> [recipient] [sender_company] [product_info]"
  puts "Examples:"
  puts "  ruby main.rb 'Microsoft'"
  puts "  ruby main.rb 'Google' 'Sundar Pichai'"
  puts "  ruby main.rb 'Amazon' 'Jeff Bezos' 'Acme Corp' 'AI-powered cloud solutions'"
  puts ""
  puts "Optional parameters:"
  puts "  recipient: specific person to email"
  puts "  sender_company: your company name"
  puts "  product_info: what you're selling/offering"
  exit 1
end

# Parse arguments
company_name = ARGV[0]
recipient = ARGV[1]
sender_company = ARGV[2]
product_info = ARGV[3]

# Run the pipeline
result = Orchestrator.run(
  company_name, 
  recipient: recipient,
  sender_company: sender_company,
  product_info: product_info
)

# Display final output
puts "\n" + "="*80
puts "CAMPAIGN OUTPUT"
puts "="*80
puts "\nTarget: #{result[:recipient] || 'General'}"
puts "Company: #{result[:company]}"
puts "\n" + "-"*80
puts "GENERATED EMAIL:"
puts "-"*80
puts result[:email]
puts "\n" + "="*80
puts "Sources used: #{result[:sources].length}"
puts "="*80
