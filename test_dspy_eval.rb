#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'
require_relative 'lib/evaluation/dspy_ade_evaluator'

DSPy.configure do |c|
  c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
end

puts "🧪 Test DSPy.rb Evaluation (10 examples)"

# Load small sample
loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data
test_examples = training_data[:classification_examples][:test].first(10)

puts "Loaded #{test_examples.size} examples"

# Test Direct Pipeline
evaluator = DSPyADEEvaluator.new(ADEDirectPipeline)

results = evaluator.evaluate(test_examples, sample_size: 10)

evaluator.print_results("Test DSPy Evaluation")

puts "\nDetailed Results:"
puts "  Total examples: #{results[:total_examples]}"
puts "  False negatives: #{results[:missed_ades]}"
puts "  Recall: #{(results[:recall] * 100).round(1)}%"
puts "  F1: #{(results[:f1] * 100).round(1)}%"