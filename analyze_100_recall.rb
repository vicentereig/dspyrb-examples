#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'

DSPy.configure do |c|
  c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
end

puts "🔍 INVESTIGATING THE SUSPICIOUS 100% RECALL"
puts "=" * 60

loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data

# Test with a larger sample
test_examples = training_data[:classification_examples][:test].first(50)
pipeline = ADEDirectPipeline.new

false_negatives = []
confusing_cases = []

puts "Testing #{test_examples.size} examples to find false negatives..."

test_examples.each_with_index do |example, i|
  input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
  expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
  
  result = pipeline.predict(input_values[:text])
  
  predicted = result[:has_ade]
  actual = expected_values[:has_ade]
  
  # Look for false negatives - cases where actual=true but predicted=false
  if actual && !predicted
    false_negatives << {
      index: i,
      text: input_values[:text][0..200],
      confidence: result[:confidence],
      reasoning: result[:reasoning]
    }
  end
  
  # Also look for confusing cases - low confidence predictions
  if result[:confidence] < 0.7
    reasoning_snippet = result[:reasoning] ? result[:reasoning][0..100] : "No reasoning"
    confusing_cases << {
      index: i,
      predicted: predicted,
      actual: actual,
      confidence: result[:confidence],
      text: input_values[:text][0..150],
      reasoning: reasoning_snippet
    }
  end
  
  print "\r  Progress: #{i+1}/#{test_examples.size}"
end

puts "\n"

# Calculate true metrics
total_actual_positives = test_examples.count { |ex| 
  expected = ex.respond_to?(:expected_values) ? ex.expected_values : ex[:expected]
  expected[:has_ade]
}

puts "📊 REAL RESULTS:"
puts "  Total actual positive cases: #{total_actual_positives}"
puts "  False negatives found: #{false_negatives.size}"
puts "  True recall: #{((total_actual_positives - false_negatives.size).to_f / total_actual_positives * 100).round(1)}%"

if false_negatives.any?
  puts "\n❌ FALSE NEGATIVES (Missed ADEs):"
  false_negatives.each_with_index do |fn, i|
    puts "\n#{i+1}. Confidence: #{fn[:confidence]}"
    puts "   Text: #{fn[:text]}..."
    puts "   Reasoning: #{fn[:reasoning]}"
  end
else
  puts "\n🚨 STILL NO FALSE NEGATIVES FOUND!"
  puts "\nPossible explanations:"
  puts "1. **GPT-4o-mini is actually very good** at medical ADE detection"
  puts "2. **Test set bias** - ADE Corpus V2 may have very obvious cases"
  puts "3. **Model is overpredicting positives** and being conservative"
  puts "4. **Dataset quality** - ground truth labels are very clear"
end

if confusing_cases.any?
  puts "\n🤔 LOW CONFIDENCE CASES (< 0.7):"
  confusing_cases.first(3).each_with_index do |case_data, i|
    puts "\n#{i+1}. Predicted: #{case_data[:predicted]} | Actual: #{case_data[:actual]} | Confidence: #{case_data[:confidence]}"
    puts "   Text: #{case_data[:text]}..."
    puts "   Reasoning: #{case_data[:reasoning]}" if case_data[:reasoning]
  end
end

puts "\n💡 HYPOTHESIS TESTING:"
puts "If recall is truly 100%, we should see:"
puts "✓ High precision on positive predictions (minimal false positives)"
puts "✓ Conservative model behavior (doesn't guess positive lightly)"  
puts "✓ Clear reasoning for all positive predictions"
puts "✓ Very obvious ADE cases in the dataset"