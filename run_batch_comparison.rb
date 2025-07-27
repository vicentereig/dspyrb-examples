#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'optparse'
require 'fileutils'
require 'time'
require_relative 'changelog_generator/batch_signatures'
require_relative 'changelog_generator/batch_modules'
require_relative 'changelog_generator/pricing'

# Parse command line options
options = {
  limit: nil,
  file: 'fixtures/llm-changelog-generator/data/feb-pull-requests.json',
  batch_size: 3,
  model: 'openai/gpt-4o-mini',
  report: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby run_batch_comparison.rb [options]"
  
  opts.on("-l", "--limit LIMIT", Integer, "Limit the number of PRs to process") do |limit|
    options[:limit] = limit
  end
  
  opts.on("-f", "--file FILE", "JSON file with PR data (default: fixtures/llm-changelog-generator/data/feb-pull-requests.json)") do |file|
    options[:file] = file
  end
  
  opts.on("-b", "--batch-size SIZE", Integer, "Batch size for processing (default: 3)") do |size|
    options[:batch_size] = size
  end
  
  opts.on("-m", "--model MODEL", "Model to use (default: openai/gpt-4o-mini)") do |model|
    options[:model] = model
  end
  
  opts.on("-r", "--report", "Generate detailed report") do
    options[:report] = true
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Token tracking variables
$token_events = []
$api_calls = []
$start_time = Time.now

# Setup instrumentation
DSPy::Instrumentation.subscribe('dspy.lm.tokens') do |event|
  $token_events << {
    input_tokens: event.payload[:input_tokens] || 0,
    output_tokens: event.payload[:output_tokens] || 0,
    total_tokens: event.payload[:total_tokens] || 0,
    timestamp: Time.now
  }
end

DSPy::Instrumentation.subscribe('dspy.lm.request') do |event|
  $api_calls << {
    duration_ms: event.payload[:duration_ms] || 0,
    timestamp: Time.now
  }
end

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
  config.lm = DSPy::LM.new(options[:model], api_key: ENV.fetch(options[:model].include?('anthropic') ? 'ANTHROPIC_API_KEY' : 'OPENAI_API_KEY'))
  config.instrumentation.enabled = true
end

# Run batch changelog generation
puts "🔄 Generating changelog with batch processing..."
puts "🤖 Model: #{options[:model]}"
puts "📦 Batch size: #{options[:batch_size]}"
puts "=" * 60

generator = ChangelogGenerator::Batch::BatchChangelogGenerator.new
result = generator.call(pull_requests: sample_prs, month: "July", year: 2025, batch_size: options[:batch_size])

$end_time = Time.now

puts "\n📊 Generated MDX Changelog:"
puts "=" * 60
puts result.mdx_content
puts "=" * 60

# Calculate totals
total_input_tokens = $token_events.sum { |e| e[:input_tokens] }
total_output_tokens = $token_events.sum { |e| e[:output_tokens] }
total_tokens = total_input_tokens + total_output_tokens
total_duration_ms = $api_calls.sum { |c| c[:duration_ms] }
api_call_count = $api_calls.length

# Calculate cost
cost = Pricing.calculate_cost(
  model: options[:model],
  input_tokens: total_input_tokens,
  output_tokens: total_output_tokens
)

puts "\n\n✅ Batch Processing Complete!"

# Token usage summary
puts "\n📊 Token Usage Summary:"
puts "- Input Tokens: #{total_input_tokens}"
puts "- Output Tokens: #{total_output_tokens}"
puts "- Total Tokens: #{total_tokens}"
puts "- Tokens per PR: #{(total_tokens.to_f / sample_prs.length).round(1)}"

# API calls summary
puts "\n📞 API Calls Summary:"
puts "- Total API Calls: #{api_call_count}"
puts "- Total Duration: #{(total_duration_ms / 1000.0).round(1)}s"
puts "- Average Duration per Call: #{(total_duration_ms.to_f / api_call_count).round}ms"

# Cost summary
puts "\n💰 Cost Summary:"
puts "- Input Cost: $#{sprintf('%.4f', cost[:input_cost])}"
puts "- Output Cost: $#{sprintf('%.4f', cost[:output_cost])}"
puts "- Total Cost: $#{sprintf('%.4f', cost[:total])}"
puts "- Cost per PR: $#{sprintf('%.4f', cost[:total] / sample_prs.length)}"

# Additional insights
puts "\n💡 Key Insights:"
puts "- Processed #{sample_prs.length} PRs in batches of #{options[:batch_size]}"
puts "- Total batches: #{(sample_prs.length.to_f / options[:batch_size]).ceil}"
puts "- Reduced API calls by ~#{((1 - api_call_count.to_f / sample_prs.length) * 100).round}% compared to individual processing"
puts "- Themes are discovered dynamically based on PR content"

# Generate detailed report if requested
if options[:report]
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  report_path = File.join("reports/batch_processing_#{timestamp}.md")
  FileUtils.mkdir_p(File.dirname(report_path))
  
  File.open(report_path, 'w') do |f|
    f.puts "# Batch Changelog Generation Report"
    f.puts
    f.puts "**Date**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    f.puts "**Model**: #{options[:model]}"
    f.puts "**Batch Size**: #{options[:batch_size]}"
    f.puts "**Total PRs**: #{sample_prs.length}"
    f.puts "**Input File**: #{options[:file]}"
    f.puts "**Total Duration**: #{($end_time - $start_time).round(1)}s"
    f.puts
    
    f.puts "## Token Usage"
    f.puts
    f.puts "| Metric | Value |"
    f.puts "|--------|-------|"
    f.puts "| Input Tokens | #{total_input_tokens} |"
    f.puts "| Output Tokens | #{total_output_tokens} |"
    f.puts "| Total Tokens | #{total_tokens} |"
    f.puts "| Tokens per PR | #{(total_tokens.to_f / sample_prs.length).round(1)} |"
    f.puts
    
    f.puts "## API Calls"
    f.puts
    f.puts "| Call # | Input Tokens | Output Tokens | Total Tokens | Duration |"
    f.puts "|--------|--------------|---------------|--------------|----------|"
    
    $token_events.each_with_index do |event, i|
      duration = $api_calls[i] ? "#{$api_calls[i][:duration_ms]}ms" : "N/A"
      f.puts "| #{i + 1} | #{event[:input_tokens]} | #{event[:output_tokens]} | #{event[:total_tokens]} | #{duration} |"
    end
    
    f.puts
    f.puts "## Cost Analysis"
    f.puts
    f.puts "| Component | Cost |"
    f.puts "|-----------|------|"
    f.puts "| Input | $#{sprintf('%.4f', cost[:input_cost])} |"
    f.puts "| Output | $#{sprintf('%.4f', cost[:output_cost])} |"
    f.puts "| **Total** | **$#{sprintf('%.4f', cost[:total])}** |"
    f.puts "| Per PR | $#{sprintf('%.4f', cost[:total] / sample_prs.length)} |"
    f.puts "| Per 1K Tokens | $#{sprintf('%.4f', (cost[:total] / total_tokens) * 1000)} |"
    
    f.puts
    f.puts "## Efficiency Metrics"
    f.puts
    f.puts "- **Batches Processed**: #{(sample_prs.length.to_f / options[:batch_size]).ceil}"
    f.puts "- **API Call Reduction**: #{((1 - api_call_count.to_f / sample_prs.length) * 100).round(1)}%"
    f.puts "- **Average Tokens per Batch**: #{(total_tokens.to_f / api_call_count).round(1)}"
    
    # Save the output
    output_path = File.join("reports/outputs/batch_changelog_#{timestamp}.md")
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, result.mdx_content)
    f.puts
    f.puts "## Generated Output"
    f.puts
    f.puts "Output saved to: `reports/outputs/batch_changelog_#{timestamp}.md`"
  end
  
  puts "\n📄 Detailed report saved to: #{report_path}"
end