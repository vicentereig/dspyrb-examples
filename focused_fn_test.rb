#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'

DSPy.configure { |c| c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY']) }

loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data
test_examples = training_data[:classification_examples][:test].first(75)
pipeline = ADEDirectPipeline.new

puts "🔍 Focused False Negative Hunt (75 examples)"
puts "=" * 50

fn_count = 0
total_positives = 0
false_negatives = []

test_examples.each_with_index do |example, i|
  input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
  expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
  
  if expected_values[:has_ade]
    total_positives += 1
    result = pipeline.predict(input_values[:text])
    
    unless result[:has_ade]  # This is a false negative!
      fn_count += 1
      false_negatives << {
        text: input_values[:text],
        confidence: result[:confidence],
        reasoning: result[:reasoning]
      }
      
      puts "🚨 FALSE NEGATIVE #{fn_count} FOUND!"
      puts "  Expected: ADE present"  
      puts "  Predicted: No ADE"
      puts "  Confidence: #{result[:confidence]}"
      puts "  Text: #{input_values[:text][0..200]}..."
      puts "  Reasoning: #{result[:reasoning][0..150]}..."
      puts
    end
  end
  
  print "\r  Progress: #{i+1}/75, Positives: #{total_positives}, FN: #{fn_count}"
end

puts "\n"
puts "📊 FOCUSED FALSE NEGATIVE RESULTS:"
puts "  Total positive cases tested: #{total_positives}"
puts "  False negatives found: #{fn_count}"
recall = total_positives > 0 ? ((total_positives - fn_count).to_f / total_positives * 100).round(1) : 0
puts "  Recall: #{recall}%"

if fn_count == 0
  puts "\n🚨 DATASET BIAS CONFIRMED!"
  puts "100% recall on #{total_positives} positive cases suggests:"
  puts "• ADE Corpus V2 contains only very obvious ADE cases"
  puts "• Published medical literature has clear causation language"
  puts "• Dataset designed for training, not real-world ambiguity"
  puts "• GPT-4o-mini + obvious cases = perfect performance"
else
  puts "\n✅ More realistic results:"
  puts "Found #{fn_count} ambiguous cases where model missed ADEs"
end