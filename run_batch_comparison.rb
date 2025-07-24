#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require_relative 'changelog_generator/batch_signatures'
require_relative 'changelog_generator/batch_modules'
require_relative 'changelog_generator/batch_changelog_generator'

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

# Configure DSPy
DSPy.configure do |config|
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV.fetch('OPENAI_API_KEY'))
end

# Run batch changelog generation
puts "🔄 Generating changelog with batch processing..."
puts "=" * 60

generator = ChangelogGenerator::Batch::BatchChangelogGenerator.new
themes = generator.generate_themes(pull_requests: sample_prs, batch_size: 3)

puts "\n📊 Themes Discovered:"
themes.each do |theme|
  puts "\n## #{theme.name}"
  puts theme.description
  puts "PRs: #{theme.pr_ids.join(', ')}"
end

puts "\n\n✅ Batch Processing Complete!"
puts "=" * 60

# Additional insights
puts "\n💡 Key Insights:"
puts "- Processed #{sample_prs.length} PRs in batches of 3"
puts "- Discovered #{themes.length} themes dynamically"
puts "- Reduced API calls by ~#{((1 - (sample_prs.length / 3.0).ceil.to_f / sample_prs.length) * 100).round}%"
puts "- Themes are discovered based on PR content, not predefined categories"