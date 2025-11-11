#!/usr/bin/env ruby
# frozen_string_literal: true

# Coverage Check Script
# This script helps identify coverage gaps by comparing routes, controllers, and feature files

require 'json'
require 'yaml'

class CoverageChecker
  def initialize
    @routes = extract_routes
    @features = extract_features
    @controllers = extract_controllers
  end

  def check
    puts "=" * 80
    puts "Cucumber Test Coverage Analysis"
    puts "=" * 80
    puts

    check_api_endpoints
    check_controllers
    check_feature_files
    generate_report
  end

  private

  def extract_routes
    # This would need to be run in Rails context
    # For now, we'll use a static list based on routes.rb
    {
      'campaigns' => {
        'index' => 'GET /api/v1/campaigns',
        'create' => 'POST /api/v1/campaigns',
        'update' => 'PUT /api/v1/campaigns/:id',
        'destroy' => 'DELETE /api/v1/campaigns/:id',
        'send_emails' => 'POST /api/v1/campaigns/:id/send_emails'
      },
      'leads' => {
        'index' => 'GET /api/v1/leads',
        'create' => 'POST /api/v1/leads',
        'update' => 'PUT /api/v1/leads/:id',
        'destroy' => 'DELETE /api/v1/leads/:id',
        'run_agents' => 'POST /api/v1/leads/:id/run_agents',
        'agent_outputs' => 'GET /api/v1/leads/:id/agent_outputs',
        'update_agent_output' => 'PATCH /api/v1/leads/:id/update_agent_output'
      },
      'agent_configs' => {
        'index' => 'GET /api/v1/campaigns/:campaign_id/agent_configs',
        'show' => 'GET /api/v1/campaigns/:campaign_id/agent_configs/:id',
        'create' => 'POST /api/v1/campaigns/:campaign_id/agent_configs',
        'update' => 'PUT /api/v1/campaigns/:campaign_id/agent_configs/:id',
        'destroy' => 'DELETE /api/v1/campaigns/:campaign_id/agent_configs/:id'
      },
      'api_keys' => {
        'show' => 'GET /api/v1/api_keys',
        'update' => 'PUT /api/v1/api_keys'
      }
    }
  end

  def extract_features
    feature_files = Dir.glob('features/**/*.feature')
    feature_files.map do |file|
      {
        name: File.basename(file, '.feature'),
        path: file,
        scenarios: count_scenarios(file)
      }
    end
  end

  def extract_controllers
    controller_files = Dir.glob('app/controllers/api/v1/*_controller.rb')
    controller_files.map do |file|
      {
        name: File.basename(file, '_controller.rb'),
        path: file,
        actions: extract_actions(file)
      }
    end
  end

  def count_scenarios(file)
    content = File.read(file)
    content.scan(/^\s*Scenario:/).count
  end

  def extract_actions(file)
    content = File.read(file)
    actions = content.scan(/def\s+(\w+)/).flatten
    actions.reject { |a| a.start_with?('_') || a == 'initialize' }
  end

  def check_api_endpoints
    puts "API Endpoint Coverage:"
    puts "-" * 80

    @routes.each do |resource, endpoints|
      puts "\n#{resource.upcase}:"
      endpoints.each do |action, route|
        covered = feature_covers_endpoint?(resource, action)
        status = covered ? "✅" : "❌"
        puts "  #{status} #{route}"
      end
    end
    puts
  end

  def check_controllers
    puts "Controller Coverage:"
    puts "-" * 80

    @controllers.each do |controller|
      puts "\n#{controller[:name].upcase} Controller:"
      controller[:actions].each do |action|
        covered = feature_covers_action?(controller[:name], action)
        status = covered ? "✅" : "❌"
        puts "  #{status} #{action}"
      end
    end
    puts
  end

  def check_feature_files
    puts "Feature Files:"
    puts "-" * 80
    puts "Total: #{@features.count} feature files"
    total_scenarios = @features.sum { |f| f[:scenarios] }
    puts "Total Scenarios: #{total_scenarios}"
    puts
  end

  def feature_covers_endpoint?(resource, action)
    # Simple keyword matching - could be improved
    keywords = {
      'campaigns' => ['campaign'],
      'leads' => ['lead'],
      'agent_configs' => ['agent_config', 'agent config'],
      'api_keys' => ['api_key', 'api key']
    }

    resource_keywords = keywords[resource] || [resource]
    action_keywords = [action]

    @features.any? do |feature|
      feature_name = feature[:name].downcase
      resource_keywords.any? { |kw| feature_name.include?(kw) } &&
        (action_keywords.any? { |kw| feature_name.include?(kw) } || action == 'index')
    end
  end

  def feature_covers_action?(controller_name, action)
    # Similar to feature_covers_endpoint? but for controller actions
    feature_covers_endpoint?(controller_name, action)
  end

  def generate_report
    puts "=" * 80
    puts "Coverage Report Summary"
    puts "=" * 80

    total_endpoints = @routes.values.sum { |e| e.count }
    covered_endpoints = @routes.sum do |resource, endpoints|
      endpoints.count { |action, _| feature_covers_endpoint?(resource, action) }
    end

    coverage_percentage = (covered_endpoints.to_f / total_endpoints * 100).round(2)

    puts "\nEndpoint Coverage: #{covered_endpoints}/#{total_endpoints} (#{coverage_percentage}%)"
    puts "Feature Files: #{@features.count}"
    puts "Total Scenarios: #{@features.sum { |f| f[:scenarios] }}"
    puts

    if coverage_percentage < 100
      puts "⚠️  Some endpoints may not be fully covered."
      puts "   Review COVERAGE_ANALYSIS.md for detailed gap analysis."
    else
      puts "✅ All endpoints appear to be covered!"
    end
  end
end

# Run the checker if executed directly
if __FILE__ == $0
  # Change to project root
  Dir.chdir(File.join(File.dirname(__FILE__), '..'))

  checker = CoverageChecker.new
  checker.check
end

