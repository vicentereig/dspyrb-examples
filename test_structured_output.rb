#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'dspy'
require_relative 'changelog_generator/signatures'
require_relative 'changelog_generator/structured_output_signatures'
require_relative 'changelog_generator/structured_output_modules'

# Quick test of DSPy.rb structured output implementation
def test_structured_output
  puts "🧪 Testing DSPy.rb Structured Output Implementation"
  puts "=" * 50
  
  # Configure DSPy with structured outputs enabled
  DSPy.configure do |config|
    config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
                            api_key: ENV.fetch('OPENAI_API_KEY'),
                            structured_outputs: true)
    # Enable structured output configuration
    config.structured_outputs.strategy = DSPy::Strategy::Strict
    config.structured_outputs.retry_enabled = true
    config.structured_outputs.max_retries = 3
    config.structured_outputs.fallback_enabled = true
  end
  
  # Load sample PR data
  path = 'fixtures/llm-changelog-generator/data/feb-pull-requests.json'
  content = File.read(path, encoding: 'UTF-8')
  data = JSON.parse(content)
  
  # Take first 5 PRs for testing
  test_prs = data.first(5).map do |pr|
    ChangelogGenerator::PullRequest.new(
      pr: pr["pr"],
      title: pr["title"],
      description: pr["description"],
      ellipsis_summary: pr["ellipsis_summary"]
    )
  end
  
  puts "📊 Testing with #{test_prs.length} PRs"
  puts
  
  # Test BatchPRAnalyzer with structured outputs
  puts "1️⃣  Testing BatchPRAnalyzerModule with structured outputs..."
  analyzer = ChangelogGenerator::StructuredOutput::BatchPRAnalyzerModule.new
  
  begin
    result = analyzer.call(pr_batch: test_prs)
    puts "   ✅ Success! Found #{result.themes.length} themes"
    result.themes.each do |theme|
      puts "   - #{theme.name}: #{theme.pr_ids.length} PRs"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
    puts e.backtrace.first(5)
  end
  
  puts
  puts "✅ Structured output test complete!"
end

# Run the test
test_structured_output