#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'optparse'
require_relative 'changelog_generator/batch_signatures'
require_relative 'changelog_generator/batch_modules'

# Parse command line options
options = {
  limit: nil,
  file: 'fixtures/llm-changelog-generator/data/feb-pull-requests.json'
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby run_batch_comparison.rb [options]"
  
  opts.on("-l", "--limit LIMIT", Integer, "Limit the number of PRs to process") do |limit|
    options[:limit] = limit
  end
  
  opts.on("-f", "--file FILE", "JSON file with PR data (default: fixtures/llm-changelog-generator/data/feb-pull-requests.json)") do |file|
    options[:file] = file
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Load PR data from fixtures
begin
  pr_data = JSON.parse(File.read(options[:file], encoding: 'UTF-8'))
rescue Errno::ENOENT
  puts "Error: File not found: #{options[:file]}"
  exit 1
rescue JSON::ParserError => e
  puts "Error parsing JSON: #{e.message}"
  exit 1
end

# Apply limit if specified
if options[:limit]
  pr_data = pr_data.first(options[:limit])
  puts "📌 Limited to #{options[:limit]} PRs"
end

# Convert JSON data to PullRequest objects
sample_prs = pr_data.map do |pr|
  ChangelogGenerator::PullRequest.new(
    pr: pr["pr"],
    title: pr["title"],
    description: pr["description"],
    ellipsis_summary: pr["ellipsis_summary"]
  )
end

puts "📄 Loaded #{sample_prs.length} PRs from #{options[:file]}"

# Configure DSPy
DSPy.configure do |config|
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV.fetch('OPENAI_API_KEY'))
end

# Run batch changelog generation
puts "🔄 Generating changelog with batch processing..."
puts "=" * 60

generator = ChangelogGenerator::Batch::BatchChangelogGenerator.new
result = generator.call(pull_requests: sample_prs, month: "July", year: 2025, batch_size: 3)

puts "\n📊 Generated MDX Changelog:"
puts "=" * 60
puts result.mdx_content
puts "=" * 60

puts "\n\n✅ Batch Processing Complete!"

# Additional insights
puts "\n💡 Key Insights:"
puts "- Processed #{sample_prs.length} PRs in batches of 3"
puts "- Reduced API calls by ~#{((1 - (sample_prs.length / 3.0).ceil.to_f / sample_prs.length) * 100).round}%"
puts "- Themes are discovered dynamically based on PR content"