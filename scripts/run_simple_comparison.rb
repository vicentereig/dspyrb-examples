#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'dspy'
require 'json'

require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/pipeline/ade_pipeline'
require_relative '../lib/evaluation/extraction_metrics'
require_relative '../lib/evaluation/classification_metrics'

class SimpleComparisonRunner
  def initialize
    @results = {}
  end

  def run
    puts "🏥 ADE Pipeline Simple Comparison"
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

    # Load dataset
    puts "\n📥 Loading ADE dataset..."
    loader = AdeDatasetLoader.new
    training_data = loader.prepare_training_data
    
    # Use proper test set with statistical significance
    # Use actual test split (not validation) and larger sample
    test_examples = training_data[:classification_examples][:test].first(200)
    puts "📊 Using #{test_examples.size} examples for evaluation (statistically meaningful sample)"

    # Test baseline pipeline
    puts "\n🧪 Testing baseline pipeline..."
    baseline_pipeline = ADEPipeline.new
    baseline_metrics = evaluate_pipeline(baseline_pipeline, test_examples, "Baseline")
    @results[:baseline] = baseline_metrics

    # Print results summary
    print_results_summary
    
    # Save results
    save_results

    puts "\n✅ Simple comparison complete!"
  end

  private

  def evaluate_pipeline(pipeline, examples, label)
    puts "  Evaluating #{label}..."
    
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
        result = pipeline.predict(text)
        
        # Collect results
        predictions << result[:has_ade]
        ground_truth << expected_values[:has_ade]
        
        drug_predictions << result[:drugs]
        drug_ground_truth << input_values[:drugs] || []
        
        effect_predictions << result[:effects]
        effect_ground_truth << input_values[:effects] || []
        
        print "\r    Progress: #{i + 1}/#{examples.size}"
        
      rescue StandardError => e
        puts "\n    ⚠️  Error processing example #{i}: #{e.message}"
        
        # Add defaults
        predictions << false
        ground_truth << expected_values[:has_ade]
        
        drug_predictions << []
        drug_ground_truth << input_values[:drugs] || []
        
        effect_predictions << []
        effect_ground_truth << input_values[:effects] || []
      end
    end
    
    puts ""
    
    # Calculate metrics
    drug_metrics = ExtractionMetrics.calculate_metrics(drug_predictions, drug_ground_truth)
    effect_metrics = ExtractionMetrics.calculate_metrics(effect_predictions, effect_ground_truth)
    classification_metrics = ClassificationMetrics.calculate_metrics(predictions, ground_truth)
    safety_metrics = ClassificationMetrics.medical_safety_metrics(predictions, ground_truth)
    
    {
      drug_extraction: drug_metrics,
      effect_extraction: effect_metrics,
      classification: classification_metrics,
      safety: safety_metrics,
      examples_evaluated: examples.size
    }
  end

  def print_results_summary
    puts "\n📊 BASELINE PIPELINE RESULTS"
    puts "=" * 50
    
    baseline = @results[:baseline]
    
    puts "Drug Extraction Performance:"
    puts "  Precision: #{(baseline[:drug_extraction][:precision] * 100).round(1)}%"
    puts "  Recall:    #{(baseline[:drug_extraction][:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(baseline[:drug_extraction][:f1] * 100).round(1)}%"
    
    puts "\nEffect Extraction Performance:"
    puts "  Precision: #{(baseline[:effect_extraction][:precision] * 100).round(1)}%"
    puts "  Recall:    #{(baseline[:effect_extraction][:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(baseline[:effect_extraction][:f1] * 100).round(1)}%"
    
    puts "\nADE Classification Performance:"
    puts "  Accuracy:  #{(baseline[:classification][:accuracy] * 100).round(1)}%"
    puts "  Precision: #{(baseline[:classification][:precision] * 100).round(1)}%"
    puts "  Recall:    #{(baseline[:classification][:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(baseline[:classification][:f1] * 100).round(1)}%"
    
    puts "\nMedical Safety Metrics:"
    puts "  False Negative Rate: #{(baseline[:safety][:false_negative_rate] * 100).round(1)}%"
    puts "  Missed ADEs: #{baseline[:safety][:missed_ades]} cases"
    puts "  False Alarms: #{baseline[:safety][:false_alarms]} cases"
    
    # Overall assessment
    overall_f1 = baseline[:classification][:f1]
    fnr = baseline[:safety][:false_negative_rate]
    
    if overall_f1 > 0.8 && fnr < 0.15
      puts "\n✅ Excellent baseline performance!"
    elsif overall_f1 > 0.7 && fnr < 0.25
      puts "\n✅ Good baseline performance - ready for optimization"
    elsif overall_f1 > 0.6
      puts "\n⚠️  Baseline needs improvement - optimization should help"
    else
      puts "\n❌ Poor baseline performance - check data and signatures"
    end
  end

  def save_results
    require 'fileutils'
    
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    results_data = {
      timestamp: timestamp,
      model: 'gpt-4o-mini',
      pipeline_type: 'baseline_only',
      results: @results
    }
    
    filename = "results/baseline_comparison_#{timestamp}.json"
    File.write(filename, JSON.pretty_generate(results_data))
    
    puts "\n💾 Results saved to #{filename}"
  end
end

# Run the comparison
if __FILE__ == $0
  runner = SimpleComparisonRunner.new
  runner.run
end