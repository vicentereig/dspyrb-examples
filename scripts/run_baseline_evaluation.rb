#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'dspy'
require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/pipeline/ade_pipeline'
require_relative '../lib/evaluation/extraction_metrics'
require_relative '../lib/evaluation/classification_metrics'

class BaselineEvaluation
  def initialize
    @loader = AdeDatasetLoader.new
    @pipeline = nil
  end

  def run
    puts "🏥 ADE Pipeline Baseline Evaluation"
    puts "=" * 50

    # Configure DSPy
    api_key = ENV['OPENAI_API_KEY']
    unless api_key
      puts "❌ Please configure OPENAI_API_KEY in .env file"
      exit 1
    end

    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: api_key)
    end

    puts "✅ DSPy configured with gpt-4o-mini"

    # Load and prepare data
    puts "\n📥 Loading dataset..."
    training_data = @loader.prepare_training_data
    
    # Initialize pipeline
    @pipeline = ADEPipeline.new
    
    # Evaluate on validation set (smaller for baseline)
    val_examples = training_data[:classification_examples][:val]
    test_size = [val_examples.size, 50].min  # Limit for baseline testing
    test_examples = val_examples.sample(test_size)
    
    puts "\n🧪 Evaluating baseline pipeline on #{test_examples.size} examples..."
    
    # Run evaluation
    results = evaluate_pipeline(test_examples)
    
    # Print results
    print_evaluation_results(results)
    
    # Save results
    save_results(results)
    
    puts "\n✅ Baseline evaluation complete!"
  end

  private

  def evaluate_pipeline(examples)
    predictions = []
    ground_truth = []
    
    drug_predictions = []
    drug_ground_truth = []
    
    effect_predictions = []
    effect_ground_truth = []
    
    examples.each_with_index do |example, i|
      begin
        # Get input and expected values
        input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
        expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
        
        text = input_values[:text]
        
        # Run pipeline prediction
        result = @pipeline.predict(text)
        
        # Collect classification results
        predictions << result[:has_ade]
        ground_truth << expected_values[:has_ade]
        
        # Collect extraction results
        drug_predictions << result[:drugs]
        drug_ground_truth << input_values[:drugs]
        
        effect_predictions << result[:effects]
        effect_ground_truth << input_values[:effects]
        
        # Progress indicator
        print "\rProgress: #{i + 1}/#{examples.size}" if (i + 1) % 5 == 0
        
      rescue StandardError => e
        puts "\n⚠️  Error processing example #{i}: #{e.message}"
        
        # Add default values for failed predictions
        predictions << false
        ground_truth << expected_values[:has_ade]
        
        drug_predictions << []
        drug_ground_truth << input_values[:drugs]
        
        effect_predictions << []
        effect_ground_truth << input_values[:effects]
      end
    end
    
    puts "\n"
    
    # Calculate all metrics
    drug_metrics = ExtractionMetrics.calculate_metrics(drug_predictions, drug_ground_truth)
    effect_metrics = ExtractionMetrics.calculate_metrics(effect_predictions, effect_ground_truth)
    classification_metrics = ClassificationMetrics.calculate_metrics(predictions, ground_truth)
    safety_metrics = ClassificationMetrics.medical_safety_metrics(predictions, ground_truth)
    
    {
      drug_extraction: drug_metrics,
      effect_extraction: effect_metrics,
      classification: classification_metrics,
      safety: safety_metrics,
      examples_processed: examples.size
    }
  end

  def print_evaluation_results(results)
    puts "\n📊 BASELINE EVALUATION RESULTS"
    puts "=" * 60
    
    ExtractionMetrics.print_metrics(results[:drug_extraction], "Drug Extraction Performance")
    ExtractionMetrics.print_metrics(results[:effect_extraction], "Effect Extraction Performance")
    ClassificationMetrics.print_metrics(results[:classification], "ADE Classification Performance", results[:safety])
    
    puts "\n🎯 SUMMARY"
    puts "=" * 30
    puts "Drug Extraction F1:    #{(results[:drug_extraction][:f1] * 100).round(1)}%"
    puts "Effect Extraction F1:  #{(results[:effect_extraction][:f1] * 100).round(1)}%"
    puts "Classification F1:     #{(results[:classification][:f1] * 100).round(1)}%"
    puts "False Negative Rate:   #{(results[:safety][:false_negative_rate] * 100).round(1)}%"
    puts "Examples processed:    #{results[:examples_processed]}"
  end

  def save_results(results)
    require 'json'
    require 'fileutils'
    
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    baseline_results = {
      timestamp: timestamp,
      model: 'gpt-4o-mini',
      pipeline_type: 'baseline',
      results: results
    }
    
    filename = "results/baseline_evaluation_#{timestamp}.json"
    File.write(filename, JSON.pretty_generate(baseline_results))
    
    puts "\n💾 Results saved to #{filename}"
  end
end

# Run evaluation if this file is executed directly
if __FILE__ == $0
  evaluation = BaselineEvaluation.new
  evaluation.run
end