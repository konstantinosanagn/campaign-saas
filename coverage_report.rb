require "json"

# Simple helper script to print uncovered lines from SimpleCov's .resultset.json
data = JSON.parse(File.read("coverage/.resultset.json"))
coverage = data.values.first["coverage"]

coverage.each do |file, info|
  lines = info["lines"]
  next unless lines

  uncovered = []
  lines.each_with_index do |count, idx|
    uncovered << idx + 1 if count.zero?
  end

  next if uncovered.empty?

  puts file
  puts "Uncovered lines: #{uncovered.join(", ")}"
end
