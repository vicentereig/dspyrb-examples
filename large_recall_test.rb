#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'

DSPy.configure do |c|
  c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
end

puts "🔍 LARGE-SCALE 100% RECALL INVESTIGATION"
puts "=" * 60

loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data

# Test with much larger sample
test_examples = training_data[:classification_examples][:test].first(100)
pipeline = ADEDirectPipeline.new

false_negatives = []
low_confidence_cases = []
confusion_matrix = { tp: 0, fp: 0, tn: 0, fn: 0 }

puts "Testing #{test_examples.size} examples (this will take ~3 minutes)..."

test_examples.each_with_index do |example, i|
  begin
    input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
    expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
    
    result = pipeline.predict(input_values[:text])
    
    predicted = result[:has_ade]
    actual = expected_values[:has_ade]
    confidence = result[:confidence]
    
    # Update confusion matrix
    if predicted && actual
      confusion_matrix[:tp] += 1
    elsif predicted && !actual
      confusion_matrix[:fp] += 1
    elsif !predicted && !actual
      confusion_matrix[:tn] += 1
    else # !predicted && actual - THE CRUCIAL CASE
      confusion_matrix[:fn] += 1
      false_negatives << {
        index: i,
        text: input_values[:text][0..300],
        confidence: confidence,
        reasoning: result[:reasoning],
        error_type: "MISSED ADE"
      }
    end
    
    # Track low confidence cases
    if confidence < 0.6
      low_confidence_cases << {
        index: i,
        predicted: predicted,
        actual: actual,
        confidence: confidence,
        text: input_values[:text][0..200]
      }
    end
    
    if (i + 1) % 10 == 0
      print "\r  Progress: #{i+1}/#{test_examples.size} [TP:#{confusion_matrix[:tp]} FP:#{confusion_matrix[:fp]} TN:#{confusion_matrix[:tn]} FN:#{confusion_matrix[:fn]}]"
    end
    
  rescue StandardError => e
    puts "\n  Error on example #{i}: #{e.message}"
  end
end

puts "\n"

# Calculate comprehensive metrics
tp, fp, tn, fn = confusion_matrix.values
total = tp + fp + tn + fn
total_actual_positives = tp + fn
total_predicted_positives = tp + fp

accuracy = (tp + tn).to_f / total
precision = tp > 0 ? tp.to_f / (tp + fp) : 0.0
recall = total_actual_positives > 0 ? tp.to_f / (tp + fn) : 0.0
f1 = (precision + recall) > 0 ? 2 * precision * recall / (precision + recall) : 0.0

puts "📊 LARGE-SCALE RESULTS (#{total} examples):"
puts "=" * 40
puts "Confusion Matrix:"
puts "  True Positives:  #{tp}"
puts "  False Positives: #{fp}" 
puts "  True Negatives:  #{tn}"
puts "  False Negatives: #{fn} #{fn > 0 ? '⚠️' : '✅'}"
puts ""
puts "Performance Metrics:"
puts "  Accuracy:  #{(accuracy * 100).round(1)}%"
puts "  Precision: #{(precision * 100).round(1)}%"
puts "  Recall:    #{(recall * 100).round(1)}% #{recall == 1.0 ? '🚨' : '✅'}"
puts "  F1 Score:  #{(f1 * 100).round(1)}%"
puts ""
puts "Model Behavior Analysis:"
puts "  Total actual positives: #{total_actual_positives}"
puts "  Total predicted positives: #{total_predicted_positives}"
puts "  Positive prediction rate: #{(total_predicted_positives.to_f / total * 100).round(1)}%"
puts "  Ground truth positive rate: #{(total_actual_positives.to_f / total * 100).round(1)}%"

if fn == 0
  puts "\n🚨 STILL PERFECT RECALL ON #{total} EXAMPLES!"
  puts "\nThis strongly suggests:"
  puts "1. ADE Corpus V2 dataset contains only very obvious ADE cases"
  puts "2. GPT-4o-mini has exceptional medical text understanding"
  puts "3. Published medical literature has clear causation language"
  puts "4. Dataset is curated for training, not real-world ambiguity"
else
  puts "\n✅ Found #{fn} false negatives - more realistic!"
  puts "\nFalse Negative Cases:"
  false_negatives.each_with_index do |case_info, i|
    puts "\n#{i+1}. Confidence: #{case_info[:confidence]}"
    puts "   Text: #{case_info[:text]}..."
    puts "   Reasoning: #{case_info[:reasoning]}"
  end
end

if low_confidence_cases.any?
  puts "\n🤔 LOW CONFIDENCE CASES (< 0.6):"
  low_confidence_cases.first(3).each_with_index do |case_info, i|
    puts "\n#{i+1}. Pred: #{case_info[:predicted]} | Actual: #{case_info[:actual]} | Conf: #{case_info[:confidence]}"
    puts "   #{case_info[:text]}..."
  end
else
  puts "\n🚨 No low confidence cases found - model is very confident!"
end

puts "\n💭 CONCLUSION:"
if fn == 0 && total >= 100
  puts "100% recall on 100+ examples suggests dataset bias rather than evaluation error."
  puts "ADE Corpus V2 likely contains only obvious, unambiguous cases from literature."
  puts "Real-world medical data would have much more ambiguous cases."
else
  puts "Results are more realistic with false negatives appearing at scale."
end