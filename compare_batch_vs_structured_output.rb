#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'optparse'
require_relative 'changelog_generator/signatures'
require_relative 'changelog_generator/token_usage_comparator'

# Script to compare batch processing vs structured output token usage
class BatchVsStructuredOutputComparison
  def initialize(options = {})
    @pr_limit = options[:pr_limit]
    @batch_sizes = options[:batch_sizes] || [1, 5, 10, 20]
    @comparator = ChangelogGenerator::TokenUsageComparator.new
  end

  def run
    puts "🚀 DSPy.rb 0.13.0 Structured Output Comparison"
    puts "=" * 70
    puts
    
    # Load PR data
    pull_requests = load_pr_data
    
    # Run comparison
    @comparator.run_comparison(
      pull_requests: pull_requests,
      batch_sizes: @batch_sizes
    )
  end

  private

  def load_pr_data
    path = 'fixtures/llm-changelog-generator/data/feb-pull-requests.json'
    content = File.read(path, encoding: 'UTF-8')
    data = JSON.parse(content)
    
    # Apply PR limit if specified
    if @pr_limit && @pr_limit > 0
      data = data.first(@pr_limit)
    end
    
    # Convert to PullRequest objects
    data.map do |pr|
      ChangelogGenerator::PullRequest.new(
        pr: pr["pr"],
        title: pr["title"],
        description: pr["description"],
        ellipsis_summary: pr["ellipsis_summary"]
      )
    end
  end
end

# Parse command line options
options = {
  pr_limit: nil,
  batch_sizes: [1, 5, 10, 20]
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  
  opts.on("-l", "--limit N", Integer, "Limit number of PRs to process") do |n|
    options[:pr_limit] = n
  end
  
  opts.on("-b", "--batch-sizes SIZES", "Comma-separated batch sizes (default: 1,5,10,20)") do |sizes|
    options[:batch_sizes] = sizes.split(',').map(&:to_i)
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Run the comparison
comparison = BatchVsStructuredOutputComparison.new(options)
comparison.run