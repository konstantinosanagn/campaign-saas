#!/usr/bin/env ruby
# frozen_string_literal: true

# Show uncovered lines from SimpleCov coverage report
# This helps identify which lines need Cucumber test coverage

require 'json'
require 'pathname'

def parse_simplecov_result
  # Try coverage directory first, then root
  result_file = Pathname.new('coverage/.resultset.json')
  result_file = Pathname.new('.resultset.json') unless result_file.exist?
  
  unless result_file.exist?
    puts "❌ Coverage result file not found."
    puts "   Run: COVERAGE=true bundle exec cucumber"
    return nil
  end

  JSON.parse(File.read(result_file))
rescue JSON::ParserError => e
  puts "❌ Error parsing coverage file: #{e.message}"
  nil
end

def extract_uncovered_lines(coverage_data)
  uncovered_files = []
  
  coverage_data.each do |command_name, command_data|
    next unless command_data['coverage']
    
    command_data['coverage'].each do |file_path, file_data|
      # file_data is a hash with 'lines' key
      lines = file_data.is_a?(Hash) && file_data.key?('lines') ? file_data['lines'] : file_data
      lines = [] unless lines.is_a?(Array)
      
      # Normalize path (handle both relative and absolute paths)
      normalized_path = file_path.gsub(/^.*?([\/\\]app[\/\\])/, 'app/')
      
      # Skip test files, migrations, and config
      next if file_path.include?('/spec/') ||
              file_path.include?('/features/') ||
              file_path.include?('\\spec\\') ||
              file_path.include?('\\features\\') ||
              file_path.include?('/config/') ||
              file_path.include?('\\config\\') ||
              file_path.include?('/db/migrate/') ||
              file_path.include?('\\db\\migrate\\') ||
              file_path.include?('/vendor/') ||
              file_path.include?('\\vendor\\') ||
              file_path.include?('/bin/') ||
              file_path.include?('\\bin\\')
      
      # Only show app/ files
      next unless file_path.include?('app/') || file_path.include?('app\\')
      
      uncovered = []
      lines.each_with_index do |count, line_num|
        # Line numbers are 1-indexed in SimpleCov
        line_number = line_num + 1
        # nil means the line is not relevant (comments, blank, etc.)
        # 0 means the line is relevant but not covered
        # 1+ means the line is covered (number = execution count)
        if count == 0
          uncovered << line_number
        end
      end
      
      # Always add files, but only show uncovered lines if they exist
      coverage_percent = calculate_coverage(lines)
      
      # Only include files with uncovered lines OR files below threshold
      if uncovered.any? || coverage_percent < 80.0
        # Use relative path for display
        display_path = file_path.gsub(/^.*?([\/\\]app[\/\\])/, 'app/').gsub(/\\/, '/')
        
        uncovered_files << {
          file: display_path,
          coverage: coverage_percent,
          uncovered_lines: uncovered,
          total_uncovered: uncovered.length
        }
      end
    end
  end
  
  uncovered_files.sort_by { |f| [f[:coverage], -f[:total_uncovered]] }
end

def calculate_coverage(lines)
  # Ensure lines is an array
  lines = lines.is_a?(Array) ? lines : []
  
  relevant_lines = lines.count { |count| !count.nil? }
  covered_lines = lines.count { |count| count.is_a?(Numeric) && count > 0 }
  
  return 100.0 if relevant_lines == 0
  
  (covered_lines.to_f / relevant_lines * 100).round(2)
end

def show_uncovered_lines(uncovered_files, min_coverage: 80.0)
  puts "=" * 100
  puts "UNCOVERED LINES IN CUCUMBER TESTS"
  puts "=" * 100
  puts
  puts "Files with coverage below #{min_coverage}% or with uncovered lines:"
  puts
  
  files_below_threshold = uncovered_files.select { |f| f[:coverage] < min_coverage }
  
  if files_below_threshold.empty?
    puts "✅ All files have #{min_coverage}%+ coverage!"
    puts
  else
    files_below_threshold.each do |file_info|
      puts "📄 #{file_info[:file]}"
      puts "   Coverage: #{file_info[:coverage]}% (#{file_info[:total_uncovered]} uncovered lines)"
      puts "   Uncovered lines: #{file_info[:uncovered_lines].join(', ')}"
      puts
    end
  end
  
  # Show summary
  total_uncovered = uncovered_files.sum { |f| f[:total_uncovered] }
  avg_coverage = uncovered_files.empty? ? 100.0 : (uncovered_files.sum { |f| f[:coverage] } / uncovered_files.length).round(2)
  
  puts "=" * 100
  puts "SUMMARY"
  puts "=" * 100
  puts "Total files with uncovered lines: #{uncovered_files.length}"
  puts "Total uncovered lines: #{total_uncovered}"
  puts "Average coverage: #{avg_coverage}%"
  puts "Files below #{min_coverage}%: #{files_below_threshold.length}"
  puts
  
  # Group by category
  categories = {
    'Controllers' => uncovered_files.select { |f| f[:file].include?('app/controllers') },
    'Models' => uncovered_files.select { |f| f[:file].include?('app/models') },
    'Services' => uncovered_files.select { |f| f[:file].include?('app/services') },
    'Jobs' => uncovered_files.select { |f| f[:file].include?('app/jobs') },
    'Mailers' => uncovered_files.select { |f| f[:file].include?('app/mailers') },
    'Helpers' => uncovered_files.select { |f| f[:file].include?('app/helpers') }
  }
  
  puts "=" * 100
  puts "BY CATEGORY"
  puts "=" * 100
  categories.each do |category, files|
    next if files.empty?
    
    total_lines = files.sum { |f| f[:total_uncovered] }
    avg_cov = (files.sum { |f| f[:coverage] } / files.length).round(2)
    
    puts "#{category}:"
    puts "  Files: #{files.length}"
    puts "  Uncovered lines: #{total_lines}"
    puts "  Average coverage: #{avg_cov}%"
    puts
  end
  
  # Show priority files (lowest coverage)
  puts "=" * 100
  puts "PRIORITY FILES (Lowest Coverage)"
  puts "=" * 100
  uncovered_files.first(10).each do |file_info|
    puts "#{file_info[:file]}: #{file_info[:coverage]}% (#{file_info[:total_uncovered]} uncovered lines)"
  end
  puts
  
  puts "💡 Tip: Open coverage/index.html in your browser for detailed line-by-line coverage"
  puts "   Run: start coverage/index.html (Windows) or open coverage/index.html (Mac/Linux)"
end

def main
  coverage_data = parse_simplecov_result
  return unless coverage_data
  
  uncovered_files = extract_uncovered_lines(coverage_data)
  
  if uncovered_files.empty?
    puts "✅ No uncovered lines found!"
    return
  end
  
  show_uncovered_lines(uncovered_files, min_coverage: 80.0)
end

main if __FILE__ == $PROGRAM_NAME

