# frozen_string_literal: true

require 'dspy'
require_relative '../pipeline/ade_pipeline'
require_relative '../pipeline/ade_direct_pipeline'
require_relative '../signatures/ade_direct_classifier'
require_relative '../evaluation/classification_metrics'

# Comprehensive optimizer for both ADE pipeline architectures
class ComprehensiveOptimizer
  attr_reader :config

  def initialize(config: {})
    @config = {
      max_examples_per_optimizer: 10,
      display_progress: true,
      test_sample_size: 20
    }.merge(config)
  end

  # Compare all approaches: baseline multi-stage, baseline direct, optimized multi-stage, optimized direct
  def comprehensive_comparison(training_data)
    puts "🏥 Comprehensive ADE Pipeline Comparison"
    puts "=" * 60
    
    results = {
      timestamp: Time.now.iso8601,
      test_sample_size: @config[:test_sample_size],
      approaches: {}
    }

    test_examples = training_data[:classification_examples][:test].first(@config[:test_sample_size])
    puts "📊 Testing on #{test_examples.size} examples"

    # 1. Baseline Multi-Stage Pipeline
    puts "\n1️⃣ Testing Baseline Multi-Stage Pipeline (3 API calls)..."
    baseline_multi = ADEPipeline.new
    multi_baseline_metrics = evaluate_classification_pipeline(baseline_multi, test_examples, "Multi-Stage Baseline")
    results[:approaches][:multi_stage_baseline] = multi_baseline_metrics

    # 2. Baseline Direct Pipeline
    puts "\n2️⃣ Testing Baseline Direct Pipeline (1 API call)..."
    baseline_direct = ADEDirectPipeline.new
    direct_baseline_metrics = evaluate_classification_pipeline(baseline_direct, test_examples, "Direct Baseline")
    results[:approaches][:direct_baseline] = direct_baseline_metrics

    # 3. Optimized Direct Pipeline (focus on the simpler approach first)
    puts "\n3️⃣ Optimizing Direct Pipeline with SimpleOptimizer..."
    optimized_direct_metrics = optimize_direct_pipeline(training_data, test_examples)
    results[:approaches][:direct_optimized] = optimized_direct_metrics

    # 4. Generate comparison analysis
    results[:comparison] = generate_comprehensive_analysis(results[:approaches])
    results[:recommendations] = generate_recommendations(results[:approaches])

    results
  rescue StandardError => e
    puts "❌ Comprehensive comparison failed: #{e.message}"
    { error: e.message, backtrace: e.backtrace.first(5) }
  end

  private

  def optimize_direct_pipeline(training_data, test_examples)
    begin
      # Prepare training examples for the direct classifier
      classification_training = training_data[:classification_examples][:train]
        .first(@config[:max_examples_per_optimizer])

      puts "  Using #{classification_training.size} examples for optimization"

      # Create baseline direct pipeline for comparison
      baseline_direct = ADEDirectPipeline.new
      baseline_metrics = evaluate_classification_pipeline(baseline_direct, test_examples, "Direct Baseline (pre-opt)")

      # Create and configure SimpleOptimizer
      optimizer = DSPy::Teleprompt::SimpleOptimizer.new

      # Optimize the direct classifier
      optimized_classifier = optimizer.compile(
        DSPy::Predict.new(ADEDirectClassifier),
        classification_training
      )

      # Create optimized pipeline
      optimized_pipeline = ADEDirectPipeline.new
      optimized_pipeline.instance_variable_set(:@ade_classifier, optimized_classifier)

      # Evaluate optimized pipeline
      optimized_metrics = evaluate_classification_pipeline(optimized_pipeline, test_examples, "Direct Optimized")

      # Calculate improvements
      improvement_analysis = calculate_improvements(baseline_metrics, optimized_metrics)

      {
        **optimized_metrics,
        baseline_comparison: baseline_metrics,
        improvements: improvement_analysis,
        optimization_method: 'SimpleOptimizer',
        training_examples_used: classification_training.size
      }

    rescue StandardError => e
      puts "  ❌ Direct pipeline optimization failed: #{e.message}"
      {
        error: e.message,
        optimization_method: 'SimpleOptimizer',
        fallback_to_baseline: true
      }
    end
  end

  def evaluate_classification_pipeline(pipeline, examples, label)
    puts "  Evaluating #{label}..."
    
    predictions = []
    ground_truth = []
    total_api_calls = 0
    processing_errors = 0
    processing_times = []

    examples.each_with_index do |example, i|
      begin
        start_time = Time.now
        
        # Get input and expected values
        input_values = example.respond_to?(:input_values) ? example.input_values : example[:input]
        expected_values = example.respond_to?(:expected_values) ? example.expected_values : example[:expected]
        
        text = input_values[:text]
        
        # Run pipeline prediction
        result = pipeline.predict(text)
        
        processing_time = Time.now - start_time
        processing_times << processing_time
        
        # Collect results
        predictions << result[:has_ade]
        ground_truth << expected_values[:has_ade]
        
        # Track API usage
        total_api_calls += result[:api_calls] || 1
        
        processing_errors += 1 if result[:error]
        
        print "\r    Progress: #{i + 1}/#{examples.size}" if @config[:display_progress]
        
      rescue StandardError => e
        puts "\n    ⚠️  Error processing example #{i}: #{e.message}"
        processing_errors += 1
        
        # Add defaults for safety
        predictions << false  # Conservative default
        ground_truth << expected_values[:has_ade]
        total_api_calls += 1
        processing_times << 0.0
      end
    end
    
    puts "" if @config[:display_progress]
    
    # Calculate comprehensive metrics
    classification_metrics = ClassificationMetrics.calculate_metrics(predictions, ground_truth)
    safety_metrics = ClassificationMetrics.medical_safety_metrics(predictions, ground_truth)
    
    # Performance metrics
    avg_processing_time = processing_times.sum / processing_times.size
    estimated_cost = total_api_calls * 0.00015  # Rough estimate for gpt-4o-mini
    
    {
      classification: classification_metrics,
      safety: safety_metrics,
      performance: {
        examples_evaluated: examples.size,
        total_api_calls: total_api_calls,
        api_calls_per_prediction: total_api_calls.to_f / examples.size,
        processing_errors: processing_errors,
        avg_processing_time: avg_processing_time.round(3),
        estimated_cost_usd: estimated_cost.round(6)
      }
    }
  end

  def calculate_improvements(baseline, optimized)
    return { error: "Missing baseline or optimized data" } if !baseline[:classification] || !optimized[:classification]

    baseline_f1 = baseline[:classification][:f1]
    optimized_f1 = optimized[:classification][:f1]
    
    baseline_fnr = baseline[:safety][:false_negative_rate]
    optimized_fnr = optimized[:safety][:false_negative_rate]

    {
      f1_improvement: {
        baseline: (baseline_f1 * 100).round(1),
        optimized: (optimized_f1 * 100).round(1),
        absolute_change: ((optimized_f1 - baseline_f1) * 100).round(1),
        relative_change: baseline_f1 > 0 ? (((optimized_f1 - baseline_f1) / baseline_f1) * 100).round(1) : 0
      },
      safety_improvement: {
        baseline_fnr: (baseline_fnr * 100).round(1),
        optimized_fnr: (optimized_fnr * 100).round(1),
        fnr_reduction: ((baseline_fnr - optimized_fnr) * 100).round(1)
      }
    }
  end

  def generate_comprehensive_analysis(approaches)
    return { error: "Insufficient data for analysis" } unless approaches.size >= 2

    analysis = {
      cost_efficiency: {},
      performance_comparison: {},
      architecture_insights: {}
    }

    # Extract key metrics for comparison
    if approaches[:multi_stage_baseline] && approaches[:direct_baseline]
      multi_api_calls = approaches[:multi_stage_baseline][:performance][:api_calls_per_prediction]
      direct_api_calls = approaches[:direct_baseline][:performance][:api_calls_per_prediction]
      
      multi_f1 = approaches[:multi_stage_baseline][:classification][:f1]
      direct_f1 = approaches[:direct_baseline][:classification][:f1]

      analysis[:cost_efficiency] = {
        api_call_ratio: (multi_api_calls / direct_api_calls).round(1),
        cost_savings_pct: (((multi_api_calls - direct_api_calls) / multi_api_calls) * 100).round(0),
        performance_trade_off_pct: ((direct_f1 - multi_f1) / multi_f1 * 100).round(1)
      }
    end

    # Optimization effectiveness
    if approaches[:direct_baseline] && approaches[:direct_optimized] && 
       !approaches[:direct_optimized][:error]
      
      baseline_f1 = approaches[:direct_baseline][:classification][:f1]
      optimized_f1 = approaches[:direct_optimized][:classification][:f1]

      analysis[:optimization_effectiveness] = {
        baseline_f1: (baseline_f1 * 100).round(1),
        optimized_f1: (optimized_f1 * 100).round(1),
        improvement_pct: ((optimized_f1 - baseline_f1) / baseline_f1 * 100).round(1),
        optimization_worthwhile: (optimized_f1 - baseline_f1) > 0.05  # 5% improvement threshold
      }
    end

    analysis
  end

  def generate_recommendations(approaches)
    recommendations = []

    # Cost vs Performance recommendation
    if approaches[:multi_stage_baseline] && approaches[:direct_baseline]
      multi_f1 = approaches[:multi_stage_baseline][:classification][:f1]
      direct_f1 = approaches[:direct_baseline][:classification][:f1]
      performance_diff = ((direct_f1 - multi_f1) / multi_f1 * 100).round(1)

      if performance_diff.abs < 5  # Less than 5% difference
        recommendations << {
          category: "Architecture Choice",
          recommendation: "Use Direct Pipeline",
          reasoning: "Similar performance (#{performance_diff}% difference) at 3x lower cost",
          confidence: "High"
        }
      elsif performance_diff < -10  # More than 10% worse
        recommendations << {
          category: "Architecture Choice", 
          recommendation: "Consider Multi-Stage Pipeline",
          reasoning: "Direct pipeline performs #{performance_diff.abs}% worse - cost savings may not justify performance loss",
          confidence: "Medium"
        }
      end
    end

    # Optimization recommendation
    if approaches[:direct_optimized] && !approaches[:direct_optimized][:error] &&
       approaches[:direct_optimized][:improvements]
      
      improvement = approaches[:direct_optimized][:improvements][:f1_improvement][:relative_change]
      
      if improvement > 10
        recommendations << {
          category: "Optimization",
          recommendation: "Apply SimpleOptimizer", 
          reasoning: "#{improvement}% F1 improvement with few-shot learning",
          confidence: "High"
        }
      elsif improvement > 5
        recommendations << {
          category: "Optimization",
          recommendation: "Consider SimpleOptimizer",
          reasoning: "Moderate #{improvement}% improvement - evaluate cost vs benefit",
          confidence: "Medium"
        }
      else
        recommendations << {
          category: "Optimization",
          recommendation: "Baseline sufficient",
          reasoning: "Only #{improvement}% improvement - optimization overhead may not be worthwhile",
          confidence: "Medium"
        }
      end
    end

    recommendations
  end
end