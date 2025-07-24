#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require_relative 'changelog_generator/batch_signatures'
require_relative 'changelog_generator/batch_modules'
require_relative 'changelog_generator/structured_outputs_comparison'
require_relative 'changelog_generator/pricing'

# Sample PRs for comparison
sample_prs = [
  ChangelogGenerator::PullRequest.new(
    pr: 3170,
    title: "Add PostgreSQL metrics dashboard",
    description: "Implements built-in metrics for CPU, memory, and disk usage tracking",
    ellipsis_summary: "Added comprehensive metrics dashboard for PostgreSQL instances"
  ),
  ChangelogGenerator::PullRequest.new(
    pr: 3202,
    title: "Enhance metrics API endpoints",
    description: "Adds new API endpoints for retrieving PostgreSQL performance metrics",
    ellipsis_summary: "Extended metrics API with additional endpoints"
  ),
  ChangelogGenerator::PullRequest.new(
    pr: 3312,
    title: "GitHub runner performance improvements",
    description: "Optimizes runner startup time and resource allocation",
    ellipsis_summary: "Faster GitHub runner provisioning"
  ),
  ChangelogGenerator::PullRequest.new(
    pr: 3366,
    title: "Add runner location preferences",
    description: "Allows users to specify preferred geographic locations for runners",
    ellipsis_summary: "Geographic preference support for runners"
  ),
  ChangelogGenerator::PullRequest.new(
    pr: 3401,
    title: "Fix database connection pooling",
    description: "Resolves issues with connection pool exhaustion under high load",
    ellipsis_summary: "Database connection pool fixes"
  ),
  ChangelogGenerator::PullRequest.new(
    pr: 3425,
    title: "Implement auto-scaling for workers",
    description: "Adds automatic scaling based on queue depth and processing time",
    ellipsis_summary: "Auto-scaling worker implementation"
  )
]

# Run comparison
comparison = ChangelogGenerator::Batch::StructuredOutputsComparison.new
comparison.run_comparison(pull_requests: sample_prs, batch_size: 3)

puts "\n\n📊 Batch Processing Comparison Complete!"
puts "=" * 60

# Additional insights
puts "\n💡 Key Insights:"
puts "- Batch processing reduces API calls by grouping multiple PRs"
puts "- Structured outputs ensure reliable JSON parsing"
puts "- Token usage varies by provider and model"
puts "- Cost optimization is significant with larger batches"