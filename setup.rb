#!/usr/bin/env ruby
# frozen_string_literal: true

# Shared setup for all DSPy.rb examples
require 'bundler/setup'
require 'dspy'
require 'dotenv/load'

def configure_dspy
  api_key = ENV['OPENAI_API_KEY']
  
  if api_key.nil? || api_key.empty?
    puts "⚠️  Warning: OPENAI_API_KEY not found in environment variables"
    puts "   Please set your API key in a .env file or environment variable"
    puts "   Example: OPENAI_API_KEY=your_key_here"
    puts ""
    return false
  end
  
  # Configure DSPy with file logging
  log_file = File.join(__dir__, 'log', 'development.log')
  DSPy.configure do |config|
    # Set up file logger with proper formatting
    config.logger = Dry.Logger(
      :dspy, 
      stream: log_file,
      formatter: :string,
      template: '[%<time>s] %<level>s -- %<progname>s: %<message>s'
    )
    
    # Configure language model
    config.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: api_key)
  end
  
  puts "✅ DSPy configured with OpenAI GPT-4o-mini"
  puts "📝 Logging to: #{log_file}"
  true
end

# Auto-configure when this file is loaded
configure_dspy
