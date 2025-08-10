#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 3: ReAct Agent with Tools
# This demonstrates intelligent agents that can use tools to solve complex problems

require_relative '../setup'

# Calculator Tool
class CalculatorTool < DSPy::Tools::Base
  tool_name 'calculator'
  tool_description 'Performs arithmetic operations'
  
  sig { params(operation: String, num1: Float, num2: Float).returns(T.any(Float, String)) }
  def call(operation:, num1:, num2:)
    case operation.downcase
    when 'add' then num1 + num2
    when 'subtract' then num1 - num2
    when 'multiply' then num1 * num2
    when 'divide'
      return "Error: Cannot divide by zero" if num2 == 0
      num1 / num2
    else
      "Error: Unknown operation '#{operation}'"
    end
  end
end

# Unit Converter Tool
class UnitConverterTool < DSPy::Tools::Base
  tool_name 'unit_converter'
  tool_description 'Converts between different units of measurement'
  
  sig { params(value: Float, from_unit: String, to_unit: String).returns(T.any(Float, String)) }
  def call(value:, from_unit:, to_unit:)
    conversions = {
      # Length
      'meters_to_feet' => ->(v) { v * 3.28084 },
      'feet_to_meters' => ->(v) { v / 3.28084 },
      'miles_to_km' => ->(v) { v * 1.60934 },
      'km_to_miles' => ->(v) { v / 1.60934 },
      'miles_to_kilometers' => ->(v) { v * 1.60934 },
      'kilometers_to_miles' => ->(v) { v / 1.60934 },
      
      # Temperature
      'celsius_to_fahrenheit' => ->(v) { (v * 9.0/5.0) + 32 },
      'fahrenheit_to_celsius' => ->(v) { (v - 32) * 5.0/9.0 },
      
      # Weight
      'kg_to_pounds' => ->(v) { v * 2.20462 },
      'pounds_to_kg' => ->(v) { v / 2.20462 },
      'kilograms_to_pounds' => ->(v) { v * 2.20462 },
      'pounds_to_kilograms' => ->(v) { v / 2.20462 }
    }
    
    key = "#{from_unit.downcase}_to_#{to_unit.downcase}"
    conversion = conversions[key]
    
    if conversion
      conversion.call(value.to_f).round(4)
    else
      "Error: Conversion from #{from_unit} to #{to_unit} not supported"
    end
  end
end

# Date/Time Tool
class DateTimeTool < DSPy::Tools::Base
  tool_name 'datetime'
  tool_description 'Provides current date and time information'
  
  sig { params(format: String).returns(String) }
  def call(format: 'default')
    case format.to_s.downcase
    when 'iso'
      Time.now.iso8601
    when 'date'
      Date.today.to_s
    when 'time'
      Time.now.strftime('%H:%M:%S')
    else
      Time.now.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end

class ProblemSolver < DSPy::Signature
  description "Solve problems using available tools when needed"
  
  input do
    const :problem, String
  end
  
  output do
    const :answer, String
  end
end

def run_react_agent_example
  puts "🤖 ReAct Agent with Tools Example"
  puts "=" * 50
  
  # Create tools
  calculator = CalculatorTool.new
  converter = UnitConverterTool.new
  datetime = DateTimeTool.new
  
  # Create ReAct agent with tools
  agent = DSPy::ReAct.new(ProblemSolver, tools: [calculator, converter, datetime])
  
  problems = [
    "What is 25 * 42 + 17?",
    "Convert 100 degrees Fahrenheit to Celsius",
    "If I run 5 miles every day for a week, how many kilometers total will I run?",
    "What's the current date and time?",
    "Calculate the area of a circle with radius 7.5 meters",
    "How many pounds is 68 kilograms?"
  ]
  
  problems.each_with_index do |problem, i|
    puts "\n#{i+1}. Problem: #{problem}"
    puts "   " + "-" * 40
    
    begin
      result = agent.forward(problem: problem)
      puts "   Answer: #{result.answer}"
      
      if result.respond_to?(:history) && result.history&.any?
        puts "   Steps taken: #{result.history.length}"
        result.history.each_with_index do |step, j|
          puts "     #{j+1}. #{step}"
        end
      end
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  puts "\n✅ ReAct Agent example completed!"
end

if __FILE__ == $0
  configure_dspy
  run_react_agent_example
end
