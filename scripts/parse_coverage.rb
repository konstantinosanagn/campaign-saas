#!/usr/bin/env ruby
# frozen_string_literal: true

# Parse SimpleCov HTML report and display coverage summary
require 'nokogiri'
require 'pathname'

def parse_coverage_html
  coverage_file = Pathname.new('coverage/index.html')
  
  unless coverage_file.exist?
    puts "❌ Coverage report not found. Run tests with COVERAGE=true first."
    return
  end

  html = File.read(coverage_file)
  doc = Nokogiri::HTML(html)
  
  # Extract overall coverage
  covered_percent = doc.at_css('.covered_percent')&.text&.strip
  total_files = doc.at_css('#AllFiles .file_list_container b')&.text&.to_i
  total_lines = doc.css('.t-line-summary b').first&.text&.to_i
  covered_lines = doc.css('.t-line-summary .green b').first&.text&.to_i
  missed_lines = doc.css('.t-line-summary .red b').first&.text&.to_i
  
  puts "=" * 80
  puts "Cucumber Test Coverage Report (SimpleCov)"
  puts "=" * 80
  puts
  puts "Overall Coverage: #{covered_percent}"
  puts "Total Files: #{total_files}"
  puts "Total Lines: #{total_lines} (#{covered_lines} covered, #{missed_lines} missed)"
  puts
  
  # Extract file coverage
  files = []
  doc.css('tr.t-file').each do |row|
    file_name = row.at_css('.t-file__name a')&.[]('title')
    coverage = row.at_css('.t-file__coverage')&.text&.strip
    lines = row.css('td.cell--number').map(&:text)
    
    next unless file_name && coverage
    
    files << {
      file: file_name,
      coverage: coverage.to_f,
      total_lines: lines[1].to_i,
      relevant_lines: lines[2].to_i,
      covered_lines: lines[3].to_i,
      missed_lines: lines[4].to_i
    }
  end
  
  # Group by directory
  groups = {
    'Controllers' => [],
    'Models' => [],
    'Services' => [],
    'Mailers' => [],
    'Helpers' => [],
    'Jobs' => []
  }
  
  files.each do |file|
    path = file[:file]
    if path.include?('/controllers/')
      groups['Controllers'] << file
    elsif path.include?('/models/')
      groups['Models'] << file
    elsif path.include?('/services/')
      groups['Services'] << file
    elsif path.include?('/mailers/')
      groups['Mailers'] << file
    elsif path.include?('/helpers/')
      groups['Helpers'] << file
    elsif path.include?('/jobs/')
      groups['Jobs'] << file
    end
  end
  
  # Display by group
  groups.each do |group_name, group_files|
    next if group_files.empty?
    
    total_covered = group_files.sum { |f| f[:covered_lines] }
    total_relevant = group_files.sum { |f| f[:relevant_lines] }
    group_coverage = total_relevant > 0 ? (total_covered.to_f / total_relevant * 100).round(2) : 0
    
    puts "#{group_name}:"
    puts "  Coverage: #{group_coverage}% (#{total_covered}/#{total_relevant} lines)"
    puts "  Files: #{group_files.count}"
    
    # Show files with coverage
    group_files.sort_by { |f| -f[:coverage] }.each do |f|
      status = f[:coverage] >= 80 ? "✅" : f[:coverage] >= 60 ? "⚠️" : "❌"
      puts "    #{status} #{File.basename(f[:file])}: #{f[:coverage]}% (#{f[:covered_lines]}/#{f[:relevant_lines]})"
    end
    puts
  end
  
  # Show files with low coverage
  low_coverage = files.select { |f| f[:coverage] < 80 && f[:relevant_lines] > 5 }
  if low_coverage.any?
    puts "⚠️  Files with Low Coverage (<80%):"
    low_coverage.sort_by { |f| f[:coverage] }.each do |f|
      puts "  - #{f[:file]}: #{f[:coverage]}% (#{f[:covered_lines]}/#{f[:relevant_lines]})"
    end
    puts
  end
  
  puts "=" * 80
  puts "Full Report: coverage/index.html"
  puts "=" * 80
end

# Run if executed directly
if __FILE__ == $0
  begin
    require 'nokogiri'
  rescue LoadError
    puts "❌ Nokogiri not found. Install it with: gem install nokogiri"
    exit 1
  end
  
  Dir.chdir(File.join(File.dirname(__FILE__), '..'))
  parse_coverage_html
end

