#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 2: Chain of Thought Reasoning
# This demonstrates how DSPy adds automatic reasoning steps to improve answer quality

require_relative '../setup'

class MathProblemSolver < DSPy::Signature
  description "Solve mathematical word problems with clear reasoning"
  
  input do
    const :problem, String
  end
  
  output do
    const :answer, String
  end
end

class GeneralQA < DSPy::Signature
  description "Answer questions with detailed explanations"
  
  input do
    const :question, String
  end
  
  output do
    const :answer, String
  end
end

def run_chain_of_thought_example
  puts "🧠 Chain of Thought Reasoning Example"
  puts "=" * 50
  
  # Create Chain of Thought predictors
  math_solver = DSPy::ChainOfThought.new(MathProblemSolver)
  general_qa = DSPy::ChainOfThought.new(GeneralQA)
  
  # Math problems
  math_problems = [
    "A store sells apples for $2 per pound. If you buy 3.5 pounds of apples and pay with a $10 bill, how much change will you receive?",
    "Two dice are rolled. What is the probability that the sum equals 7?",
    "A rectangle has a length of 12 meters and a width of 8 meters. What is its area and perimeter?"
  ]
  
  puts "\n📊 Math Problems:"
  puts "-" * 30
  
  math_problems.each_with_index do |problem, i|
    puts "\n#{i+1}. Problem: #{problem}"
    
    begin
      result = math_solver.call(problem: problem)
      puts "   Reasoning: #{result.reasoning}"
      puts "   Answer: #{result.answer}"
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  # General questions
  general_questions = [
    "Why do leaves change color in autumn?",
    "What causes earthquakes to occur?",
    "How does photosynthesis work in plants?"
  ]
  
  puts "\n\n🌍 General Questions:"
  puts "-" * 30
  
  general_questions.each_with_index do |question, i|
    puts "\n#{i+1}. Question: #{question}"
    
    begin
      result = general_qa.call(question: question)
      puts "   Reasoning: #{result.reasoning}"
      puts "   Answer: #{result.answer}"
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  puts "\n✅ Chain of Thought example completed!"
end

if __FILE__ == $0
  configure_dspy
  run_chain_of_thought_example
end
