#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require_relative 'changelog_generator/monolithic_comparison'

# Check for required API keys
missing_keys = []
missing_keys << 'OPENAI_API_KEY' unless ENV['OPENAI_API_KEY']
missing_keys << 'ANTHROPIC_API_KEY' unless ENV['ANTHROPIC_API_KEY']

if missing_keys.any?
  puts "❌ Missing required environment variables: #{missing_keys.join(', ')}"
  puts "Please set them in your .env file or environment"
  exit 1
end

# Configure DSPy
DSPy.configure do |config|
  config.instrumentation.enabled = true
  config.instrumentation.subscribers = [:logger]
end

# Run the comparison
puts "Starting monolithic changelog generation comparison..."
puts "=" * 60
puts

comparison = MonolithicComparison.new(month: 'May', year: 2025)
comparison.run_comparison