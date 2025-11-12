#!/usr/bin/env ruby
# frozen_string_literal: true

# Coverage Summary Script
# Reads SimpleCov coverage results and displays a summary

require 'json'
require 'pathname'

def coverage_summary
  coverage_dir = Pathname.new('coverage')
  result_file = coverage_dir + '.last_run.json'
  json_file = coverage_dir + 'coverage-final.json'

  unless result_file.exist?
    puts "❌ Coverage results not found. Run tests with COVERAGE=true first."
    puts "   Example: COVERAGE=true bundle exec cucumber"
    return
  end

  # Read the last run result
  result = JSON.parse(File.read(result_file))
  line_coverage = result.dig('result', 'line') || 0

  puts "=" * 80
  puts "Cucumber Test Coverage Summary"
  puts "=" * 80
  puts
  puts "Overall Line Coverage: #{line_coverage.round(2)}%"
  puts

  # Read detailed coverage if available
  if json_file.exist?
    coverage_data = JSON.parse(File.read(json_file))

    # Find Cucumber coverage
    cucumber_key = coverage_data.keys.find { |k| k.include?('Cucumber') || k.include?('cucumber') }

    if cucumber_key
      cucumber_coverage = coverage_data[cucumber_key]['coverage']

      # Group by directory
      groups = {
        'Controllers' => [],
        'Models' => [],
        'Services' => [],
        'Mailers' => [],
        'Helpers' => []
      }

      cucumber_coverage.each do |file_path, file_data|
        next unless file_data && file_data['lines']

        lines = file_data['lines']
        total_lines = lines.count { |l| l != nil }
        covered_lines = lines.count { |l| l && l > 0 }
        coverage_pct = total_lines > 0 ? (covered_lines.to_f / total_lines * 100).round(2) : 0

        file_info = {
          file: File.basename(file_path),
          path: file_path,
          coverage: coverage_pct,
          covered: covered_lines,
          total: total_lines
        }

        # Categorize file
        if file_path.include?('/controllers/')
          groups['Controllers'] << file_info
        elsif file_path.include?('/models/')
          groups['Models'] << file_info
        elsif file_path.include?('/services/')
          groups['Services'] << file_info
        elsif file_path.include?('/mailers/')
          groups['Mailers'] << file_info
        elsif file_path.include?('/helpers/')
          groups['Helpers'] << file_info
        end
      end

      # Display by group
      groups.each do |group_name, files|
        next if files.empty?

        total_covered = files.sum { |f| f[:covered] }
        total_lines = files.sum { |f| f[:total] }
        group_coverage = total_lines > 0 ? (total_covered.to_f / total_lines * 100).round(2) : 0

        puts "#{group_name}:"
        puts "  Coverage: #{group_coverage}% (#{total_covered}/#{total_lines} lines)"
        puts "  Files: #{files.count}"

        # Show individual files with low coverage
        low_coverage = files.select { |f| f[:coverage] < 80 && f[:total] > 10 }
        if low_coverage.any?
          puts "  ⚠️  Files with low coverage (<80%):"
          low_coverage.each do |f|
            puts "     - #{f[:file]}: #{f[:coverage]}% (#{f[:covered]}/#{f[:total]})"
          end
        end
        puts
      end
    else
      puts "⚠️  Could not find Cucumber coverage in JSON file"
      puts "   Available keys: #{coverage_data.keys.join(', ')}"
    end
  end

  puts "=" * 80
  puts "Detailed Report: coverage/index.html"
  puts "=" * 80
  puts
  puts "To view the full coverage report, open coverage/index.html in your browser."
end

# Run if executed directly
if __FILE__ == $0
  Dir.chdir(File.join(File.dirname(__FILE__), '..'))
  coverage_summary
end
