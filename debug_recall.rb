#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'

DSPy.configure do |c|
  c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
end

loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data
test_examples = training_data[:classification_examples][:test].first(8)

pipeline = ADEDirectPipeline.new

puts "🔍 Detailed prediction analysis:"
puts "=" * 60

true_positives = 0
false_positives = 0
true_negatives = 0
false_negatives = 0

test_examples.each_with_index do |example, i|
  input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
  expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
  
  result = pipeline.predict(input_values[:text])
  
  predicted = result[:has_ade]
  actual = expected_values[:has_ade]
  
  # Classification for confusion matrix
  if predicted && actual
    true_positives += 1
    outcome = "TP"
  elsif predicted && !actual
    false_positives += 1
    outcome = "FP"
  elsif !predicted && !actual
    true_negatives += 1
    outcome = "TN"
  else # !predicted && actual - THIS IS THE KEY ONE
    false_negatives += 1
    outcome = "FN - MISSED ADE!"
  end
  
  puts "Example #{i+1}: #{outcome}"
  puts "  Predicted: #{predicted} | Actual: #{actual} | Confidence: #{result[:confidence]}"
  puts "  Text: #{input_values[:text][0..150]}..."
  if result[:reasoning]
    puts "  Reasoning: #{result[:reasoning][0..100]}..."
  end
  puts
end

puts "Confusion Matrix:"
puts "  TP: #{true_positives}, FP: #{false_positives}"
puts "  FN: #{false_negatives}, TN: #{true_negatives}"

total_positives = true_positives + false_negatives
recall = total_positives > 0 ? true_positives.to_f / total_positives : 0

puts "\nRecall: #{(recall * 100).round(1)}%"
puts "False Negatives: #{false_negatives}/#{total_positives} positive cases"

if false_negatives == 0 && total_positives > 0
  puts "\n🚨 SUSPICIOUS: Zero false negatives on real medical data is highly unlikely!"
  puts "This suggests:"
  puts "1. Test set bias (only obvious cases)"
  puts "2. Model overpredicting positive cases" 
  puts "3. Ground truth labels may be incorrect"
  puts "4. Evaluation bug"
end

# Let's also check if the model is just predicting positive for everything
total_predictions = test_examples.size
positive_predictions = [true_positives, false_positives].sum
prediction_rate = positive_predictions.to_f / total_predictions

puts "\nModel behavior analysis:"
puts "  Positive prediction rate: #{(prediction_rate * 100).round(1)}%"
puts "  Ground truth positive rate: #{(test_examples.count { |ex| 
    expected = ex.respond_to?(:expected_values) ? ex.expected_values : ex[:expected]
    expected[:has_ade] 
  }.to_f / total_predictions * 100).round(1)}%"