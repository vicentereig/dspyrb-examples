#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dspy'
require 'json'
require 'dotenv/load'
require_relative 'changelog_generator/structured_outputs_comparison'

# Load sample PR data
def load_pr_data(limit: 10)
  path = File.join(__dir__, 'fixtures/llm-changelog-generator/data/may-pull-requests.json')
  content = File.read(path, encoding: 'UTF-8')
  data = JSON.parse(content)
  
  data.first(limit).map do |pr_data|
    ChangelogGenerator::PullRequest.new(
      pr: pr_data['pr'],
      title: pr_data['title'],
      description: pr_data['description'] || '',
      ellipsis_summary: pr_data['ellipsis_summary'] || ''
    )
  end
end

# Main execution
if __FILE__ == $0
  puts "🚀 Running Structured Outputs Comparison"
  puts "=" * 60
  puts
  
  # Parse command line arguments
  pr_limit = ARGV[0]&.to_i || 10
  batch_size = ARGV[1]&.to_i || 5
  
  puts "Configuration:"
  puts "  - PR limit: #{pr_limit}"
  puts "  - Batch size: #{batch_size}"
  puts
  
  # Load PR data
  pull_requests = load_pr_data(limit: pr_limit)
  puts "Loaded #{pull_requests.size} PRs"
  puts
  
  # Run comparison
  comparison = ChangelogGenerator::Batch::StructuredOutputsComparison.new
  comparison.run_comparison(pull_requests: pull_requests, batch_size: batch_size)
  
  # Save results to file
  results_file = "structured_outputs_comparison_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
  File.write(results_file, JSON.pretty_generate(comparison.results))
  puts "\n📁 Results saved to: #{results_file}"
end