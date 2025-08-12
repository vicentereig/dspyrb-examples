#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'dspy'
require 'json'

require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/pipeline/ade_pipeline'
require_relative '../lib/pipeline/ade_direct_pipeline'
require_relative '../lib/evaluation/extraction_metrics'
require_relative '../lib/evaluation/classification_metrics'

class PipelineComparisonRunner
  def initialize
    @results = {}
    @api_call_counts = {}
  end

  def run
    puts "🏥 ADE Pipeline Architecture Comparison"
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
    
    # Use proper test set with reasonable sample size for comparison
    test_examples = training_data[:classification_examples][:test].first(100)
    puts "📊 Using #{test_examples.size} examples for comparison"

    # Test both pipelines
    puts "\n🧪 Testing Multi-Stage Pipeline (3 API calls per prediction)..."
    multi_stage_pipeline = ADEPipeline.new
    multi_stage_metrics = evaluate_pipeline(multi_stage_pipeline, test_examples, "Multi-Stage", api_calls_per_prediction: 3)
    @results[:multi_stage] = multi_stage_metrics

    puts "\n🧪 Testing Direct Pipeline (1 API call per prediction)..."
    direct_pipeline = ADEDirectPipeline.new
    direct_metrics = evaluate_pipeline(direct_pipeline, test_examples, "Direct", api_calls_per_prediction: 1)
    @results[:direct] = direct_metrics

    # Print comprehensive comparison
    print_comparison_results
    
    # Save results
    save_results

    puts "\n✅ Pipeline comparison complete!"
  end

  private

  def evaluate_pipeline(pipeline, examples, label, api_calls_per_prediction:)
    puts "  Evaluating #{label}..."
    
    predictions = []
    ground_truth = []
    total_api_calls = 0
    processing_errors = 0

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
        
        # Track API usage
        total_api_calls += api_calls_per_prediction
        
        print "\r    Progress: #{i + 1}/#{examples.size}"
        
      rescue StandardError => e
        puts "\n    ⚠️  Error processing example #{i}: #{e.message}"
        processing_errors += 1
        
        # Add defaults
        predictions << false
        ground_truth << expected_values[:has_ade]
        total_api_calls += api_calls_per_prediction
      end
    end
    
    puts ""
    
    # Calculate metrics
    classification_metrics = ClassificationMetrics.calculate_metrics(predictions, ground_truth)
    safety_metrics = ClassificationMetrics.medical_safety_metrics(predictions, ground_truth)
    
    {
      classification: classification_metrics,
      safety: safety_metrics,
      examples_evaluated: examples.size,
      total_api_calls: total_api_calls,
      api_calls_per_prediction: api_calls_per_prediction,
      processing_errors: processing_errors,
      estimated_cost_usd: total_api_calls * 0.00015  # Rough estimate for gpt-4o-mini
    }
  end

  def print_comparison_results
    puts "\n📊 PIPELINE ARCHITECTURE COMPARISON"
    puts "=" * 60
    
    multi_stage = @results[:multi_stage]
    direct = @results[:direct]
    
    # Performance comparison
    puts "\n🎯 PERFORMANCE COMPARISON"
    puts "-" * 30
    
    puts "Multi-Stage Pipeline (3 API calls):"
    puts "  Accuracy:  #{(multi_stage[:classification][:accuracy] * 100).round(1)}%"
    puts "  Precision: #{(multi_stage[:classification][:precision] * 100).round(1)}%"
    puts "  Recall:    #{(multi_stage[:classification][:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(multi_stage[:classification][:f1] * 100).round(1)}%"
    puts "  False Negative Rate: #{(multi_stage[:safety][:false_negative_rate] * 100).round(1)}%"
    
    puts "\nDirect Pipeline (1 API call):"
    puts "  Accuracy:  #{(direct[:classification][:accuracy] * 100).round(1)}%"
    puts "  Precision: #{(direct[:classification][:precision] * 100).round(1)}%"
    puts "  Recall:    #{(direct[:classification][:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(direct[:classification][:f1] * 100).round(1)}%"
    puts "  False Negative Rate: #{(direct[:safety][:false_negative_rate] * 100).round(1)}%"
    
    # Cost comparison
    puts "\n💰 COST & EFFICIENCY COMPARISON"
    puts "-" * 35
    
    puts "Multi-Stage Pipeline:"
    puts "  Total API Calls: #{multi_stage[:total_api_calls]}"
    puts "  Calls per Prediction: #{multi_stage[:api_calls_per_prediction]}"
    puts "  Estimated Cost: $#{multi_stage[:estimated_cost_usd].round(4)}"
    puts "  Processing Errors: #{multi_stage[:processing_errors]}"
    
    puts "\nDirect Pipeline:"
    puts "  Total API Calls: #{direct[:total_api_calls]}"
    puts "  Calls per Prediction: #{direct[:api_calls_per_prediction]}"
    puts "  Estimated Cost: $#{direct[:estimated_cost_usd].round(4)}"
    puts "  Processing Errors: #{direct[:processing_errors]}"
    
    # Cost efficiency
    cost_ratio = multi_stage[:estimated_cost_usd] / direct[:estimated_cost_usd]
    puts "\n📈 Cost Efficiency:"
    puts "  Multi-stage is #{cost_ratio.round(1)}x more expensive than direct approach"
    
    # Performance delta
    f1_delta = (multi_stage[:classification][:f1] - direct[:classification][:f1]) * 100
    fnr_delta = (multi_stage[:safety][:false_negative_rate] - direct[:safety][:false_negative_rate]) * 100
    
    puts "\n🎯 Performance Trade-offs:"
    if f1_delta.abs < 5.0
      puts "  Similar F1 performance (#{f1_delta.round(1)}% difference)"
    elsif f1_delta > 0
      puts "  Multi-stage F1 advantage: +#{f1_delta.round(1)}%"
    else
      puts "  Direct pipeline F1 advantage: +#{f1_delta.abs.round(1)}%"
    end
    
    if fnr_delta.abs < 2.0
      puts "  Similar safety profile (#{fnr_delta.round(1)}% FNR difference)"
    elsif fnr_delta > 0
      puts "  Direct pipeline safer: -#{fnr_delta.round(1)}% FNR"
    else
      puts "  Multi-stage pipeline safer: -#{fnr_delta.abs.round(1)}% FNR"
    end
    
    # Recommendation
    puts "\n💡 RECOMMENDATION"
    puts "-" * 20
    
    if f1_delta.abs < 3.0 && fnr_delta.abs < 3.0
      puts "✅ Direct pipeline recommended: similar performance at 3x lower cost"
    elsif f1_delta > 5.0 && fnr_delta < -5.0
      puts "⚖️  Multi-stage justified: significantly better performance"
    else
      puts "🤔 Mixed results: consider optimization before choosing architecture"
    end
  end

  def save_results
    require 'fileutils'
    
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    results_data = {
      timestamp: timestamp,
      model: 'gpt-4o-mini',
      comparison_type: 'multi_stage_vs_direct',
      test_set_size: 100,
      results: @results
    }
    
    filename = "results/pipeline_comparison_#{timestamp}.json"
    File.write(filename, JSON.pretty_generate(results_data))
    
    puts "\n💾 Results saved to #{filename}"
  end
end

# Run the comparison
if __FILE__ == $0
  runner = PipelineComparisonRunner.new
  runner.run
end