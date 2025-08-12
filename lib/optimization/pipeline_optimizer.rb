# frozen_string_literal: true

require 'dspy'
require_relative '../signatures/drug_extractor'
require_relative '../signatures/effect_extractor'
require_relative '../signatures/ade_classifier'
require_relative '../pipeline/ade_pipeline'
require_relative '../evaluation/extraction_metrics'
require_relative '../evaluation/classification_metrics'

# Optimizer for the three-signature ADE pipeline
# Supports both SimpleOptimizer and MIPROv2
class PipelineOptimizer
  attr_reader :config

  def initialize(config: {})
    @config = {
      max_errors: 3,
      display_progress: true,
      optimization_mode: 'medical_safety'
    }.merge(config)
  end

  # Optimize using SimpleOptimizer (few-shot learning)
  def optimize_with_simple_optimizer(training_data)
    puts "\n🚀 Starting SimpleOptimizer optimization..."
    
    # Extract training examples for each signature
    extraction_examples = training_data[:extraction_examples]
    classification_examples = training_data[:classification_examples]
    
    results = {
      baseline: {},
      optimized: {},
      improvements: {},
      cost_analysis: {},
      timestamp: Time.now.iso8601
    }
    
    # 1. Evaluate baseline pipeline
    puts "📊 Evaluating baseline pipeline..."
    baseline_pipeline = ADEPipeline.new
    baseline_metrics = evaluate_pipeline(baseline_pipeline, classification_examples[:val].first(20))
    results[:baseline] = baseline_metrics
    
    # 2. Optimize each signature independently
    optimized_pipeline = optimize_signatures_with_simple(extraction_examples, classification_examples)
    
    # 3. Evaluate optimized pipeline
    puts "📊 Evaluating optimized pipeline..."
    optimized_metrics = evaluate_pipeline(optimized_pipeline, classification_examples[:val].first(20))
    results[:optimized] = optimized_metrics
    
    # 4. Calculate improvements
    results[:improvements] = calculate_improvements(baseline_metrics, optimized_metrics)
    
    # 5. Generate cost analysis
    results[:cost_analysis] = generate_cost_analysis('SimpleOptimizer')
    
    results
  rescue StandardError => e
    puts "❌ SimpleOptimizer optimization failed: #{e.message}"
    { error: e.message, optimizer: 'SimpleOptimizer' }
  end

  # Optimize using MIPROv2 (bootstrap optimization)
  def optimize_with_miprov2(training_data)
    puts "\n🚀 Starting MIPROv2 optimization..."
    
    extraction_examples = training_data[:extraction_examples]
    classification_examples = training_data[:classification_examples]
    
    # Check minimum data requirements
    total_examples = classification_examples[:train].size
    if total_examples < 10
      return { 
        warning: "Insufficient training data for MIPROv2. Need at least 10 examples, got #{total_examples}",
        optimizer: 'MIPROv2'
      }
    end
    
    results = {
      baseline: {},
      optimized: {},
      improvements: {},
      cost_analysis: {},
      timestamp: Time.now.iso8601
    }
    
    # 1. Evaluate baseline pipeline
    puts "📊 Evaluating baseline pipeline..."
    baseline_pipeline = ADEPipeline.new
    baseline_metrics = evaluate_pipeline(baseline_pipeline, classification_examples[:val].first(20))
    results[:baseline] = baseline_metrics
    
    # 2. Optimize signatures with MIPROv2
    optimized_pipeline = optimize_signatures_with_miprov2(extraction_examples, classification_examples)
    
    # 3. Evaluate optimized pipeline
    puts "📊 Evaluating optimized pipeline..."
    optimized_metrics = evaluate_pipeline(optimized_pipeline, classification_examples[:val].first(20))
    results[:optimized] = optimized_metrics
    
    # 4. Calculate improvements
    results[:improvements] = calculate_improvements(baseline_metrics, optimized_metrics)
    
    # 5. Generate cost analysis
    results[:cost_analysis] = generate_cost_analysis('MIPROv2')
    
    results
  rescue StandardError => e
    puts "❌ MIPROv2 optimization failed: #{e.message}"
    { error: e.message, optimizer: 'MIPROv2' }
  end

  private

  def optimize_signatures_with_simple(extraction_examples, classification_examples)
    optimized_pipeline = ADEPipeline.new
    
    # Optimize DrugExtractor
    puts "🔧 Optimizing DrugExtractor with SimpleOptimizer..."
    if extraction_examples[:drug_extraction].any?
      drug_optimizer_config = DSPy::Teleprompt::SimpleOptimizer::OptimizerConfig.new
      drug_optimizer = DSPy::Teleprompt::SimpleOptimizer.new(config: drug_optimizer_config)
      
      training_examples = extraction_examples[:drug_extraction].first([10, extraction_examples[:drug_extraction].size].min)
      optimized_drug_extractor = drug_optimizer.compile(optimized_pipeline.drug_extractor, training_examples)
      optimized_pipeline.instance_variable_set(:@drug_extractor, optimized_drug_extractor)
    end
    
    # Optimize EffectExtractor
    puts "🔧 Optimizing EffectExtractor with SimpleOptimizer..."
    if extraction_examples[:effect_extraction].any?
      effect_optimizer_config = DSPy::Teleprompt::SimpleOptimizer::OptimizerConfig.new
      effect_optimizer = DSPy::Teleprompt::SimpleOptimizer.new(config: effect_optimizer_config)
      
      training_examples = extraction_examples[:effect_extraction].first([10, extraction_examples[:effect_extraction].size].min)
      optimized_effect_extractor = effect_optimizer.compile(optimized_pipeline.effect_extractor, training_examples)
      optimized_pipeline.instance_variable_set(:@effect_extractor, optimized_effect_extractor)
    end
    
    # Optimize ADEClassifier
    puts "🔧 Optimizing ADEClassifier with SimpleOptimizer..."
    if classification_examples[:train].any?
      classifier_optimizer_config = DSPy::Teleprompt::SimpleOptimizer::OptimizerConfig.new
      classifier_optimizer = DSPy::Teleprompt::SimpleOptimizer.new(config: classifier_optimizer_config)
      
      training_examples = classification_examples[:train].first([15, classification_examples[:train].size].min)
      optimized_ade_classifier = classifier_optimizer.compile(optimized_pipeline.ade_classifier, training_examples)
      optimized_pipeline.instance_variable_set(:@ade_classifier, optimized_ade_classifier)
    end
    
    optimized_pipeline
  end

  def optimize_signatures_with_miprov2(extraction_examples, classification_examples)
    optimized_pipeline = ADEPipeline.new
    
    # Optimize DrugExtractor
    puts "🔧 Optimizing DrugExtractor with MIPROv2..."
    if extraction_examples[:drug_extraction].size >= 5
      mipro_config = DSPy::Teleprompt::MIPROv2::MIPROv2Config.new
      mipro_config.optimization_mode = 'balanced'
      mipro_config.k_demos = [3, extraction_examples[:drug_extraction].size / 3].min
      mipro_config.num_candidates = 3
      
      mipro = DSPy::Teleprompt::MIPROv2.new(config: mipro_config)
      training_examples = extraction_examples[:drug_extraction].first(15)
      val_examples = extraction_examples[:drug_extraction].last([5, extraction_examples[:drug_extraction].size - 15].max)
      
      optimized_drug_extractor = mipro.compile(
        optimized_pipeline.drug_extractor,
        training_examples,
        validation_examples: val_examples
      )
      optimized_pipeline.instance_variable_set(:@drug_extractor, optimized_drug_extractor)
    end
    
    # Optimize EffectExtractor
    puts "🔧 Optimizing EffectExtractor with MIPROv2..."
    if extraction_examples[:effect_extraction].size >= 5
      mipro_config = DSPy::Teleprompt::MIPROv2::MIPROv2Config.new
      mipro_config.optimization_mode = 'balanced'
      mipro_config.k_demos = [3, extraction_examples[:effect_extraction].size / 3].min
      mipro_config.num_candidates = 3
      
      mipro = DSPy::Teleprompt::MIPROv2.new(config: mipro_config)
      training_examples = extraction_examples[:effect_extraction].first(15)
      val_examples = extraction_examples[:effect_extraction].last([5, extraction_examples[:effect_extraction].size - 15].max)
      
      optimized_effect_extractor = mipro.compile(
        optimized_pipeline.effect_extractor,
        training_examples,
        validation_examples: val_examples
      )
      optimized_pipeline.instance_variable_set(:@effect_extractor, optimized_effect_extractor)
    end
    
    # Optimize ADEClassifier
    puts "🔧 Optimizing ADEClassifier with MIPROv2..."
    if classification_examples[:train].size >= 10
      mipro_config = DSPy::Teleprompt::MIPROv2::MIPROv2Config.new
      mipro_config.optimization_mode = 'medical_safety'  # Focus on recall for medical safety
      mipro_config.k_demos = [5, classification_examples[:train].size / 5].min
      mipro_config.num_candidates = 5
      
      mipro = DSPy::Teleprompt::MIPROv2.new(config: mipro_config)
      training_examples = classification_examples[:train].first(25)
      val_examples = classification_examples[:val].first(15)
      
      optimized_ade_classifier = mipro.compile(
        optimized_pipeline.ade_classifier,
        training_examples,
        validation_examples: val_examples
      )
      optimized_pipeline.instance_variable_set(:@ade_classifier, optimized_ade_classifier)
    end
    
    optimized_pipeline
  end

  def evaluate_pipeline(pipeline, examples)
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
        drug_ground_truth << input_values[:drugs]
        
        effect_predictions << result[:effects]
        effect_ground_truth << input_values[:effects]
        
        print "\r  Progress: #{i + 1}/#{examples.size}" if @config[:display_progress]
        
      rescue StandardError => e
        puts "\n⚠️  Error processing example #{i}: #{e.message}"
        
        # Add default values
        predictions << false
        ground_truth << expected_values[:has_ade]
        
        drug_predictions << []
        drug_ground_truth << input_values[:drugs] || []
        
        effect_predictions << []
        effect_ground_truth << input_values[:effects] || []
      end
    end
    
    puts "" if @config[:display_progress]
    
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

  def calculate_improvements(baseline, optimized)
    improvements = {}
    
    %i[drug_extraction effect_extraction classification].each do |component|
      baseline_f1 = baseline[component][:f1]
      optimized_f1 = optimized[component][:f1]
      
      improvement_pct = baseline_f1 > 0 ? ((optimized_f1 - baseline_f1) / baseline_f1 * 100) : 0
      
      improvements[component] = {
        baseline_f1: baseline_f1,
        optimized_f1: optimized_f1,
        improvement_pct: improvement_pct.round(1)
      }
    end
    
    # Overall safety improvement
    baseline_fnr = baseline[:safety][:false_negative_rate]
    optimized_fnr = optimized[:safety][:false_negative_rate]
    fnr_improvement = baseline_fnr - optimized_fnr  # Reduction in false negative rate is good
    
    improvements[:safety] = {
      baseline_false_negative_rate: baseline_fnr,
      optimized_false_negative_rate: optimized_fnr,
      fnr_reduction: fnr_improvement.round(3)
    }
    
    improvements
  end

  def generate_cost_analysis(optimizer_type)
    # Simplified cost analysis - could be enhanced with actual API tracking
    base_cost_per_call = 0.002  # Estimated cost for gpt-4o-mini
    
    case optimizer_type
    when 'SimpleOptimizer'
      estimated_calls = 50  # Conservative estimate for simple optimization
      {
        optimizer: optimizer_type,
        estimated_api_calls: estimated_calls,
        estimated_cost: estimated_calls * base_cost_per_call,
        method: 'Few-shot optimization'
      }
    when 'MIPROv2'
      estimated_calls = 150  # More calls for bootstrap optimization
      {
        optimizer: optimizer_type,
        estimated_api_calls: estimated_calls,
        estimated_cost: estimated_calls * base_cost_per_call,
        method: 'Bootstrap optimization with candidates'
      }
    else
      { optimizer: 'Unknown', estimated_cost: 0 }
    end
  end
end