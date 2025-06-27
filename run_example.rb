#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick runner for individual examples
# Usage: ruby run_example.rb <example_number>

require_relative 'setup'

EXAMPLES = {
  '1' => 'examples/01_basic_predict.rb',
  '2' => 'examples/02_chain_of_thought.rb', 
  '3' => 'examples/03_react_agent.rb',
  '4' => 'examples/04_multi_stage_pipeline.rb',
  '5' => 'examples/05_custom_types.rb'
}

def main
  example_number = ARGV[0]
  
  unless example_number
    puts "Usage: ruby run_example.rb <example_number>"
    puts "Available examples: #{EXAMPLES.keys.join(', ')}"
    exit 1
  end
  
  example_file = EXAMPLES[example_number]
  
  unless example_file
    puts "Example #{example_number} not found"
    puts "Available examples: #{EXAMPLES.keys.join(', ')}"
    exit 1
  end
  
  file_path = File.join(__dir__, example_file)
  
  unless File.exist?(file_path)
    puts "Example file not found: #{file_path}"
    exit 1
  end
  
  # Configure DSPy
  unless configure_dspy
    puts "Please configure your API key in .env file"
    exit 1
  end
  
  # Load and run the example
  load file_path
  
  # Call the appropriate example function
  case example_number
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
end

if __FILE__ == $0
  main
end
