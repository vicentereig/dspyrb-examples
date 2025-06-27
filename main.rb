#!/usr/bin/env ruby
# frozen_string_literal: true

# DSPy.rb Examples Runner
# This script runs all examples or allows you to run individual examples

require_relative 'setup'
require 'optparse'

EXAMPLES = {
  '1' => {
    file: 'examples/01_basic_predict.rb',
    name: 'Basic Prediction',
    description: 'Demonstrates simple structured prediction with sentiment classification'
  },
  '2' => {
    file: 'examples/02_chain_of_thought.rb', 
    name: 'Chain of Thought',
    description: 'Shows reasoning capabilities with math problems and general Q&A'
  },
  '3' => {
    file: 'examples/03_react_agent.rb',
    name: 'ReAct Agent with Tools',
    description: 'Intelligent agent that uses tools to solve complex problems'
  },
  '4' => {
    file: 'examples/04_multi_stage_pipeline.rb',
    name: 'Multi-stage Pipeline',
    description: 'Complex workflow composing multiple LLM calls for article writing'
  },
  '5' => {
    file: 'examples/05_custom_types.rb',
    name: 'Complex Types & Structured Data',
    description: 'Advanced type system usage with enums, structs, and complex schemas'
  }
}

def print_banner
  puts <<~BANNER
    ╔═══════════════════════════════════════════════════════════════╗
    ║                        DSPy.rb Examples                      ║
    ║          The Ruby framework for programming LLMs             ║
    ╚═══════════════════════════════════════════════════════════════╝
  BANNER
end

def list_examples
  puts "\n📚 Available Examples:"
  puts "=" * 50
  
  EXAMPLES.each do |number, info|
    puts "#{number}. #{info[:name]}"
    puts "   #{info[:description]}"
    puts "   File: #{info[:file]}"
    puts
  end
end

def run_example(number)
  example = EXAMPLES[number.to_s]
  
  unless example
    puts "❌ Example #{number} not found"
    return false
  end
  
  file_path = File.join(__dir__, example[:file])
  
  unless File.exist?(file_path)
    puts "❌ Example file not found: #{file_path}"
    return false
  end
  
  puts "\n🚀 Running Example #{number}: #{example[:name]}"
  puts "📁 File: #{example[:file]}"
  puts "📝 Description: #{example[:description]}"
  puts
  
  # Load the example file
  load file_path
  
  # Call the appropriate example function based on the file
  case number.to_s
  when '1'
    run_basic_predict_example
  when '2'
    run_chain_of_thought_example
  when '3'
    run_react_agent_example
  when '4'
    run_multi_stage_pipeline_example
  when '5'
    run_complex_types_example
  end
  
  true
rescue StandardError => e
  puts "❌ Error running example: #{e.message}"
  puts "   #{e.backtrace.first}" if e.backtrace
  false
end

def run_all_examples
  puts "\n🔄 Running all examples in sequence..."
  puts "=" * 50
  
  EXAMPLES.each do |number, info|
    puts "\n" + "▶️ " * 20
    success = run_example(number)
    
    unless success
      puts "❌ Failed to run example #{number}"
      break
    end
    
    puts "✅ Example #{number} completed"
    
    # Add a pause between examples
    puts "\nPress Enter to continue to next example (or Ctrl+C to exit)..."
    gets unless ENV['AUTO_RUN'] == 'true'
  end
  
  puts "\n🎉 All examples completed!"
end

def main
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby main.rb [options]"
    
    opts.on("-l", "--list", "List all available examples") do
      options[:list] = true
    end
    
    opts.on("-r", "--run NUMBER", "Run specific example by number") do |number|
      options[:run] = number
    end
    
    opts.on("-a", "--all", "Run all examples") do
      options[:all] = true
    end
    
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!
  
  print_banner
  
  # Check if DSPy is properly configured
  unless configure_dspy
    puts "\n❌ Please configure your API key before running examples"
    puts "   1. Copy .env.example to .env"
    puts "   2. Add your OpenAI API key to the .env file"
    exit 1
  end
  
  if options[:list]
    list_examples
  elsif options[:run]
    run_example(options[:run])
  elsif options[:all]
    run_all_examples
  else
    # Interactive mode
    puts "\n🎮 Interactive Mode"
    puts "Choose an option:"
    puts "  1-5: Run specific example"
    puts "  a: Run all examples"
    puts "  l: List examples"
    puts "  q: Quit"
    
    loop do
      print "\nEnter your choice: "
      input = gets.chomp.downcase
      
      case input
      when 'q', 'quit', 'exit'
        puts "👋 Goodbye!"
        break
      when 'l', 'list'
        list_examples
      when 'a', 'all'
        run_all_examples
        break
      when '1', '2', '3', '4', '5'
        run_example(input)
        break
      else
        puts "❌ Invalid choice. Please enter 1-5, a, l, or q"
      end
    end
  end
end

if __FILE__ == $0
  main
end
