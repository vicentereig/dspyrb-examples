# frozen_string_literal: true

require 'dspy'
require_relative 'ade_predictor'
require_relative 'evaluation_metrics'

class ADEOptimizer
  attr_reader :config
  
  def initialize(config: {})
    @config = {
      max_errors: 3,
      display_progress: true,
      optimization_mode: 'balanced'
    }.merge(config)
    @optimization_costs = { total_cost: 0.0, baseline_cost: 0.0, optimization_cost: 0.0 }
  end
  
  # Optimize using DSPy SimpleOptimizer
  def run_simple_optimization(baseline_program:, training_examples:, num_examples: nil)
    begin
      # Validate training examples
      validation_result = validate_training_examples(training_examples)
      return validation_result if validation_result[:error]
      
      # Evaluate baseline performance and track costs
      baseline_start_cost = current_total_cost
      baseline_metrics = evaluate_program(baseline_program, training_examples)
      baseline_end_cost = current_total_cost
      @optimization_costs[:baseline_cost] += (baseline_end_cost - baseline_start_cost)
      
      # Set up optimizer configuration
      optimizer_config = DSPy::Teleprompt::SimpleOptimizer::OptimizerConfig.new
      optimizer_config.max_errors = @config[:max_errors]
      optimizer_config.max_bootstrapped_examples = num_examples || [training_examples.size, 5].min
      
      # Create the optimizer
      optimizer = DSPy::Teleprompt::SimpleOptimizer.new(config: optimizer_config)
      
      # Run optimization
      optimization_result = optimizer.compile(
        baseline_program,
        trainset: training_examples
      )
      optimized_program = optimization_result.optimized_program
      
      # Evaluate optimized performance and track costs
      optimization_start_cost = current_total_cost
      optimized_metrics = evaluate_program(optimized_program, training_examples)
      optimization_end_cost = current_total_cost
      @optimization_costs[:optimization_cost] += (optimization_end_cost - optimization_start_cost)
      @optimization_costs[:total_cost] = @optimization_costs[:baseline_cost] + @optimization_costs[:optimization_cost]
      
      # Calculate improvement
      improvement = calculate_improvement(baseline_metrics, optimized_metrics)
      
      # Generate safety analysis
      safety_analysis = analyze_safety_metrics(baseline_metrics, optimized_metrics)
      
      {
        optimized_program: optimized_program,
        baseline_metrics: baseline_metrics,
        optimized_metrics: optimized_metrics,
        improvement_percent: improvement,
        selected_examples: training_examples.first(num_examples || 5),
        history: {
          optimizer_type: 'SimpleOptimizer',
          training_examples_count: training_examples.size,
          k_demos: num_examples || [training_examples.size, 5].min,
          timestamp: Time.now.iso8601
        },
        cost_analysis: generate_cost_analysis('SimpleOptimizer'),
        safety_metrics: safety_analysis
      }
      
    rescue StandardError => e
      puts "Optimization failed: #{e.message}"
      {
        error: "SimpleOptimizer failed: #{e.message}",
        baseline_metrics: baseline_metrics || {},
        optimized_program: baseline_program
      }
    end
  end
  
  # Optimize using DSPy MIPROv2
  def run_mipro_optimization(baseline_program:, training_examples:, validation_examples:, k_demos: 3, num_candidates: 10, optimization_mode: nil)
    begin
      # Validate examples
      train_validation = validate_training_examples(training_examples)
      return train_validation if train_validation[:error]
      
      val_validation = validate_training_examples(validation_examples, "validation")
      return val_validation if val_validation[:error]
      
      # Check for sufficient data
      if training_examples.size < 3
        return { warning: "Insufficient training data for MIPROv2. Need at least 3 examples, got #{training_examples.size}" }
      end
      
      # Evaluate baseline
      baseline_metrics = evaluate_program(baseline_program, validation_examples)
      
      # Set up MIPROv2 optimizer configuration
      mipro_config = DSPy::Teleprompt::MIPROv2::MIPROv2Config.new
      mipro_config.max_errors = @config[:max_errors]
      mipro_config.max_bootstrapped_examples = k_demos
      mipro_config.num_instruction_candidates = num_candidates
      mipro_config.bootstrap_sets = [num_candidates / 2, 3].max
      
      mode = optimization_mode || @config[:optimization_mode]
      mipro_config.optimization_strategy = mode == 'recall_focused' ? 'adaptive' : 'balanced'
      
      # Create the optimizer
      mipro = DSPy::Teleprompt::MIPROv2.new(config: mipro_config)
      
      # Run optimization
      optimization_result = mipro.compile(
        baseline_program,
        trainset: training_examples,
        valset: validation_examples
      )
      optimized_program = optimization_result.optimized_program
      
      # Evaluate optimized performance
      optimized_metrics = evaluate_program(optimized_program, validation_examples)
      
      # Calculate improvement
      improvement = calculate_improvement(baseline_metrics, optimized_metrics)
      
      # Generate safety analysis
      safety_analysis = analyze_safety_metrics(baseline_metrics, optimized_metrics)
      if optimization_mode == 'recall_focused'
        safety_analysis[:recall_focus] = true
        safety_analysis[:missed_ades] = calculate_missed_ades(optimized_metrics)
      end
      
      {
        optimized_program: optimized_program,
        baseline_metrics: baseline_metrics,
        optimized_metrics: optimized_metrics,
        improvement_percent: improvement,
        candidates_explored: num_candidates,
        best_candidate_score: optimized_metrics[:f1],
        history: {
          optimizer_type: 'MIPROv2',
          training_examples_count: training_examples.size,
          validation_examples_count: validation_examples.size,
          k_demos: k_demos,
          num_candidates: num_candidates,
          bootstrap_samples: k_demos * num_candidates,
          timestamp: Time.now.iso8601
        },
        cost_analysis: generate_cost_analysis('MIPROv2'),
        safety_analysis: optimization_mode == 'recall_focused' ? safety_analysis : nil,
        safety_metrics: safety_analysis
      }
      
    rescue StandardError => e
      puts "MIPROv2 optimization failed: #{e.message}"
      {
        error: "MIPROv2 failed: #{e.message}",
        baseline_metrics: baseline_metrics || {},
        optimized_program: baseline_program
      }
    end
  end
  
  # Compare all optimization methods
  def compare_optimizers(baseline_program:, training_examples:, validation_examples:)
    results = {}
    
    # Baseline
    results[:baseline] = {
      metrics: evaluate_program(baseline_program, validation_examples),
      method: 'Baseline (zero-shot)'
    }
    
    # SimpleOptimizer
    simple_result = run_simple_optimization(
      baseline_program: baseline_program,
      training_examples: training_examples
    )
    results[:simple_optimizer] = {
      metrics: simple_result[:optimized_metrics],
      improvement: simple_result[:improvement_percent],
      method: 'SimpleOptimizer (few-shot)'
    }
    
    # MIPROv2
    mipro_result = run_mipro_optimization(
      baseline_program: baseline_program,
      training_examples: training_examples,
      validation_examples: validation_examples
    )
    results[:mipro_v2] = {
      metrics: mipro_result[:optimized_metrics],
      improvement: mipro_result[:improvement_percent],
      method: 'MIPROv2 (bootstrap)'
    }
    
    # Rank by F1 score
    ranking = results.map { |name, data| [name.to_s, data[:metrics][:f1]] }
                     .sort_by { |_, f1| -f1 }
    
    best_optimizer = ranking.first[0]
    
    # Analysis focused on medical safety
    analysis = {
      recall_focus: {
        baseline: results[:baseline][:metrics][:recall],
        simple: results[:simple_optimizer][:metrics][:recall],
        mipro: results[:mipro_v2][:metrics][:recall],
        best_recall: ranking.max_by { |_, data| results[data.to_sym][:metrics][:recall] }[0]
      },
      precision_tradeoff: {
        baseline: results[:baseline][:metrics][:precision],
        simple: results[:simple_optimizer][:metrics][:precision],
        mipro: results[:mipro_v2][:metrics][:precision]
      }
    }
    
    results.merge(
      ranking: ranking,
      best_optimizer: best_optimizer,
      analysis: analysis
    )
  end
  
  # Evaluate on held-out test set
  def evaluate_on_test_set(optimized_program:, test_examples:)
    evaluate_program(optimized_program, test_examples)
  end
  
  # Cost tracking methods
  def optimization_cost_summary
    @optimization_costs.merge({
      cost_per_example: @optimization_costs[:total_cost] > 0 ? 
        (@optimization_costs[:total_cost] / ([baseline_examples_processed, 1].max)).round(6) : 0.0,
      gpt_4o_mini_pricing: {
        input_per_1k: 0.00015,
        output_per_1k: 0.0006
      }
    })
  end

  def reset_cost_tracking
    @optimization_costs = { total_cost: 0.0, baseline_cost: 0.0, optimization_cost: 0.0 }
  end

  private
  
  def validate_training_examples(examples, type = "training")
    if examples.nil? || examples.empty?
      return { error: "Invalid #{type} examples: cannot be empty" }
    end
    
    examples.each_with_index do |example, idx|
      unless example.is_a?(DSPy::Example)
        return { error: "Invalid #{type} examples: item #{idx} is not a DSPy::Example" }
      end
      
      unless example.input_values && example.expected_values
        return { error: "Invalid #{type} examples: item #{idx} missing input or expected values" }
      end
      
      unless example.input_values[:patient_report] && example.expected_values[:ade_status]
        return { error: "Invalid #{type} examples: item #{idx} missing required fields" }
      end
    end
    
    { valid: true }
  end
  
  def evaluate_program(program, examples)
    # Extract inputs and make predictions
    inputs = examples.map { |ex| ex.input_values }
    
    predictions = inputs.map do |input|
      begin
        result = program.call(**input)
        format_program_result(result)
      rescue StandardError => e
        puts "Prediction failed: #{e.message}"
        # Return safe default
        {
          ade_status: ADEPredictor::ADEStatus::NoADE,
          confidence: 0.0,
          drug_symptom_pairs: []
        }
      end
    end
    
    # Use EvaluationMetrics to calculate performance
    EvaluationMetrics.evaluate_batch(examples, predictions)
  end
  
  def format_program_result(result)
    if result.respond_to?(:ade_status)
      {
        ade_status: result.ade_status,
        confidence: result.respond_to?(:confidence) ? result.confidence : 0.8,
        drug_symptom_pairs: result.respond_to?(:drug_symptom_pairs) ? result.drug_symptom_pairs : []
      }
    elsif result.is_a?(Hash)
      {
        ade_status: parse_ade_status(result[:ade_status]),
        confidence: result[:confidence] || 0.8,
        drug_symptom_pairs: result[:drug_symptom_pairs] || []
      }
    else
      {
        ade_status: ADEPredictor::ADEStatus::NoADE,
        confidence: 0.5,
        drug_symptom_pairs: []
      }
    end
  end
  
  def parse_ade_status(status_value)
    case status_value
    when ADEPredictor::ADEStatus
      status_value
    when String, Symbol
      case status_value.to_s.downcase
      when 'no_adverse_event', 'noade', 'none', 'no'
        ADEPredictor::ADEStatus::NoADE
      when 'mild_adverse_event', 'mildade', 'mild'
        ADEPredictor::ADEStatus::MildADE
      when 'severe_adverse_event', 'severeade', 'severe'
        ADEPredictor::ADEStatus::SevereADE
      else
        ADEPredictor::ADEStatus::NoADE
      end
    else
      ADEPredictor::ADEStatus::NoADE
    end
  end
  
  def calculate_improvement(baseline_metrics, optimized_metrics)
    baseline_f1 = baseline_metrics[:f1] || 0
    optimized_f1 = optimized_metrics[:f1] || 0
    
    return 0.0 if baseline_f1 == 0
    
    ((optimized_f1 - baseline_f1) / baseline_f1 * 100).round(2)
  end
  
  def analyze_safety_metrics(baseline_metrics, optimized_metrics)
    baseline_cm = baseline_metrics[:confusion_matrix] || {}
    optimized_cm = optimized_metrics[:confusion_matrix] || {}
    
    baseline_fn = baseline_cm[:fn] || 0
    optimized_fn = optimized_cm[:fn] || 0
    
    total_actual_ades = (baseline_cm[:tp] || 0) + baseline_fn
    
    {
      false_negative_rate: total_actual_ades > 0 ? optimized_fn.to_f / total_actual_ades : 0.0,
      critical_misses: optimized_fn,
      recall_improvement: (optimized_metrics[:recall] || 0) - (baseline_metrics[:recall] || 0)
    }
  end
  
  def calculate_missed_ades(metrics)
    cm = metrics[:confusion_matrix] || {}
    cm[:fn] || 0
  end

  def generate_cost_analysis(optimizer_type)
    {
      optimizer: optimizer_type,
      total_cost: @optimization_costs[:total_cost].round(6),
      baseline_evaluation_cost: @optimization_costs[:baseline_cost].round(6),
      optimization_cost: @optimization_costs[:optimization_cost].round(6),
      model: 'gpt-4o-mini',
      cost_breakdown: {
        input_cost_per_1k: 0.00015,
        output_cost_per_1k: 0.0006
      }
    }
  end

  def current_total_cost
    # This would ideally integrate with BaselinePredictor's cost tracking
    # For now, return 0 as a placeholder - in real implementation,
    # we'd need a shared cost tracking system
    0.0
  end

  def baseline_examples_processed
    # Track number of examples processed for cost-per-example calculation
    @baseline_examples_count ||= 0
  end
end