#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to run ADE optimization with the full Huggingface dataset
# Usage: ruby run_ade_optimization.rb [options]

require 'optparse'
require 'fileutils'
require 'dotenv/load'  # Load .env file
require_relative 'lib/dataset_loader'
require_relative 'lib/baseline_predictor'
require_relative 'lib/medical_text_extractor'
require_relative 'lib/ade_optimizer'
require_relative 'lib/evaluation_metrics'

class ADEOptimizationRunner
  def initialize(options = {})
    @options = {
      data_dir: './data',
      examples: nil,  # nil means use all
      train_ratio: 0.7,
      val_ratio: 0.15,
      test_ratio: 0.15,
      max_errors: 3,
      output_dir: './optimization_results',
      download: true
    }.merge(options)

    FileUtils.mkdir_p(@options[:output_dir])
  end

  def run
    puts "🏥 ADE Optimization with Full Dataset"
    puts "=" * 50

    # Step 1: Setup DSPy
    api_key = ENV['OPENAI_API_KEY']
    unless api_key
      puts "❌ Please configure your API key in .env file"
      exit 1
    end

    # Ensure log directory exists
    FileUtils.mkdir_p('log')

    # Configure DSPy with proper instrumentation (like working scripts)
    require 'dspy'

    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: api_key)
      
      # Configure JSON logger with file and stdout backends (per latest docs)
      c.logger = Dry.Logger(:dspy, formatter: :json) do |logger|
        logger.add_backend(level: :info, stream: $stdout)
        logger.add_backend(level: :debug, stream: "log/test.log") 
      end
    end

    puts "✅ DSPy configured with #{api_key ? 'API key loaded' : 'NO API KEY'}"
    puts "📝 JSON logging enabled - should see llm.generate events"
    
    # Test basic LLM call to verify it's working
    begin
      test_predictor = DSPy::Predict.new(MedicalTextExtractor)
      puts "🧪 Testing LLM call..."
      test_result = test_predictor.call(text: "Patient reports mild headache after taking aspirin.")
      puts "✅ LLM test call successful - extracted #{test_result.medications&.size || 0} medications"
      puts "   ↳ This should have generated llm.generate logs above ☝️"
    rescue => e
      puts "❌ LLM test call failed: #{e.message}"
      puts "   This explains why all costs are $0 - no API calls are being made!"
    end

    # Step 2: Load dataset
    dataset_loader = DatasetLoader.new(data_dir: @options[:data_dir])

    if @options[:download]
      puts "\n📥 Downloading ADE dataset from Huggingface..."
      dataset_loader.download_dataset
    end

    puts "\n📊 Loading examples from parquet files..."
    raw_examples = dataset_loader.load_examples

    if raw_examples.empty?
      puts "❌ No examples loaded. Please check if the dataset was downloaded correctly."
      exit 1
    end

    puts "✅ Loaded #{raw_examples.size} raw examples"

    # Step 3: Transform to DSPy examples
    puts "\n🔄 Transforming to DSPy examples..."
    dspy_examples = dataset_loader.transform_to_examples(raw_examples)

    # Limit examples if specified
    if @options[:examples] && @options[:examples] < dspy_examples.size
      puts "📌 Limiting to #{@options[:examples]} examples as requested"
      dspy_examples = dspy_examples.sample(@options[:examples])
    end

    puts "✅ Prepared #{dspy_examples.size} DSPy examples"

    # Step 4: Split dataset
    puts "\n✂️  Splitting dataset..."
    
    # For very small datasets, adjust ratios to ensure each split has at least 1 example
    if dspy_examples.size <= 3
      train = dspy_examples[0..-2] || []  # All but last
      val = dspy_examples[-1..-1] || []   # Last one
      test = []                           # Empty for very small sets
    else
      train, val, test = dataset_loader.split_dataset(
        dspy_examples,
        ratios: [@options[:train_ratio], @options[:val_ratio], @options[:test_ratio]],
        stratify: true
      )
    end

    puts "  Training: #{train.size} examples"
    puts "  Validation: #{val.size} examples"  
    puts "  Test: #{test.size} examples"

    # Step 5: Baseline evaluation using pipeline
    puts "\n📈 Evaluating baseline pipeline predictor..."
    baseline_predictor = ADEPipelinePredictor.new

    baseline_val_metrics = evaluate_on_dataset(baseline_predictor, val, "Baseline Pipeline (Validation)")
    baseline_test_metrics = evaluate_on_dataset(baseline_predictor, test, "Baseline Pipeline (Test)")

    # Step 6: Optimization
    puts "\n🚀 Running DSPy optimization..."
    puts "  Training examples: #{train.size}"
    puts "  Max errors: #{@options[:max_errors]}"

    optimizer = ADEOptimizer.new(config: {
      max_errors: @options[:max_errors],
      display_progress: true,
      optimization_mode: 'medical_safety'
    })

    # Create training examples with extracted features for optimization
    puts "  Extracting features for optimization..."
    extracted_train = train.map do |ex|
      input_text = ex.respond_to?(:input_values) ? ex.input_values[:text] : ex[:input][:text]
      expected_values = ex.respond_to?(:expected_values) ? ex.expected_values : ex[:expected]
      
      extracted = baseline_predictor.extractor.call(text: input_text)
      
      # Handle different return formats from extractor
      extracted_input = if extracted.respond_to?(:patient_report)
        symptoms = extracted.symptoms
        symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
        
        {
          patient_report: extracted.patient_report || '',
          medications: extracted.medications || [],
          symptoms: symptoms
        }
      elsif extracted.is_a?(Hash)
        symptoms = extracted[:symptoms] || extracted['symptoms'] || []
        symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
        
        {
          patient_report: extracted[:patient_report] || extracted['patient_report'] || '',
          medications: extracted[:medications] || extracted['medications'] || [],
          symptoms: symptoms
        }
      else
        {
          patient_report: input_text,
          medications: [],
          symptoms: []
        }
      end
      
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: extracted_input,
        expected: expected_values
      )
    end

    # Also create extracted validation examples for optimization
    extracted_val = val.map do |ex|
      input_text = ex.respond_to?(:input_values) ? ex.input_values[:text] : ex[:input][:text]
      expected_values = ex.respond_to?(:expected_values) ? ex.expected_values : ex[:expected]
      
      extracted = baseline_predictor.extractor.call(text: input_text)
      
      # Handle different return formats from extractor (same as training)
      extracted_input = if extracted.respond_to?(:patient_report)
        symptoms = extracted.symptoms
        symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
        
        {
          patient_report: extracted.patient_report || '',
          medications: extracted.medications || [],
          symptoms: symptoms
        }
      elsif extracted.is_a?(Hash)
        symptoms = extracted[:symptoms] || extracted['symptoms'] || []
        symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
        
        {
          patient_report: extracted[:patient_report] || extracted['patient_report'] || '',
          medications: extracted[:medications] || extracted['medications'] || [],
          symptoms: symptoms
        }
      else
        {
          patient_report: input_text,
          medications: [],
          symptoms: []
        }
      end
      
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: extracted_input,
        expected: expected_values
      )
    end

    optimization_result = optimizer.run_simple_optimization(
      baseline_program: baseline_predictor.predictor.program,
      training_examples: extracted_train,
      validation_examples: extracted_val,
      num_examples: [extracted_train.size, 10].min  # Use up to 10 examples for optimization
    )

    if optimization_result[:error]
      puts "❌ Optimization failed: #{optimization_result[:error]}"
      exit 1
    end

    optimized_program = optimization_result[:optimized_program]

    # Step 7: Evaluate optimized program in pipeline
    puts "\n📈 Evaluating optimized pipeline predictor..."
    optimized_pipeline = ADEPipelinePredictor.new
    optimized_pipeline.predictor.instance_variable_set(:@program, optimized_program)

    optimized_val_metrics = evaluate_on_dataset(optimized_pipeline, val, "Optimized Pipeline (Validation)")
    optimized_test_metrics = evaluate_on_dataset(optimized_pipeline, test, "Optimized Pipeline (Test)")

    # Step 8: Compare and save results
    puts "\n📊 Results Comparison"
    puts "=" * 50

    print_comparison("Validation Set", baseline_val_metrics, optimized_val_metrics)
    print_comparison("Test Set", baseline_test_metrics, optimized_test_metrics)

    # Step 9: Save detailed results
    save_results(
      baseline_val_metrics, baseline_test_metrics,
      optimized_val_metrics, optimized_test_metrics,
      optimization_result
    )

    # Step 10: Cost analysis
    if optimization_result[:cost_analysis]
      puts "\n💰 Cost Analysis"
      puts "=" * 30
      costs = optimization_result[:cost_analysis]
      puts "  Total cost: $#{costs[:total_cost].round(4)}"
      puts "  Baseline evaluation: $#{costs[:baseline_evaluation_cost].round(4)}" 
      puts "  Optimization: $#{costs[:optimization_cost].round(4)}"
      puts "  Optimizer type: #{costs[:optimizer]}"
    end

    puts "\n✅ Optimization complete! Results saved to #{@options[:output_dir]}"
  end

  private

  def evaluate_on_dataset(predictor, dataset, label)
    puts "\n  Evaluating #{label}..."

    predictions = []
    actuals = []
    correct = 0
    total = dataset.size

    dataset.each_with_index do |example, i|
      begin
        # Handle both hash and DSPy::Example formats
        if example.respond_to?(:input_values)
          input = example.input_values[:text] || example.input_values
          expected = example.expected_values
        else
          # Simple hash format from dataset loader
          input = example[:input]
          expected = example[:expected]
        end

        prediction = predictor.predict(input)

        # Store for metrics calculation
        predictions << prediction[:ade_status]
        actuals << expected[:ade_status]

        # Compare ADE status
        if prediction[:ade_status] == expected[:ade_status]
          correct += 1
        end

        # Progress indicator
        if (i + 1) % 10 == 0 || i == total - 1
          print "\r    Progress: #{i + 1}/#{total} (#{(correct.to_f / (i + 1) * 100).round(1)}% accurate)"
        end
      rescue StandardError => e
        puts "\n    Warning: Error processing example #{i}: #{e.message}"
        # Use NoADE as default for failed predictions
        predictions << ADEPredictor::ADEStatus::NoADE
        
        # Handle expected values for error case
        expected_ade = if example.respond_to?(:expected_values)
          example.expected_values[:ade_status]
        else
          example[:expected][:ade_status]
        end
        actuals << expected_ade
      end
    end

    puts  # New line after progress

    # Calculate metrics using EvaluationMetrics class methods
    cm = EvaluationMetrics.confusion_matrix(predictions, actuals)
    precision = EvaluationMetrics.calculate_precision(cm[:tp], cm[:fp])
    recall = EvaluationMetrics.calculate_recall(cm[:tp], cm[:fn])
    f1 = EvaluationMetrics.calculate_f1_score(precision, recall)
    accuracy = total > 0 ? correct.to_f / total : 0.0

    {
      accuracy: accuracy,
      precision: precision,
      recall: recall,
      f1: f1,
      correct: correct,
      total: total,
      confusion_matrix: cm
    }
  end

  def print_comparison(dataset_name, baseline, optimized)
    puts "\n#{dataset_name}:"
    puts "  Metric     | Baseline | Optimized | Improvement"
    puts "  -----------|----------|-----------|------------"

    [:accuracy, :precision, :recall, :f1].each do |metric|
      baseline_val = baseline[metric]
      optimized_val = optimized[metric]
      improvement = optimized_val - baseline_val
      improvement_pct = baseline_val > 0 ? (improvement / baseline_val * 100) : 0

      puts "  #{metric.to_s.capitalize.ljust(10)} | #{format_metric(baseline_val)} | #{format_metric(optimized_val)} | #{format_improvement(improvement_pct)}"
    end
  end

  def format_metric(value)
    if value.nil? || value.nan?
      "    0.0%".rjust(8)
    else
      "#{(value * 100).round(2)}%".rjust(8)
    end
  end

  def format_improvement(value)
    sign = value >= 0 ? "+" : ""
    "#{sign}#{value.round(1)}%"
  end

  def save_results(baseline_val, baseline_test, optimized_val, optimized_test, optimization_result)
    results = {
      timestamp: Time.now.iso8601,
      options: @options,
      baseline: {
        validation: baseline_val,
        test: baseline_test
      },
      optimized: {
        validation: optimized_val,
        test: optimized_test
      },
      optimization: {
        improvement_percent: optimization_result[:improvement_percent],
        cost_analysis: optimization_result[:cost_analysis],
        optimizer_metrics: {
          baseline: optimization_result[:baseline_metrics],
          optimized: optimization_result[:optimized_metrics]
        },
        safety_metrics: optimization_result[:safety_metrics],
        history: optimization_result[:history],
        selected_examples_count: optimization_result[:selected_examples]&.size || 0
      }
    }

    # Save as JSON
    File.write(
      File.join(@options[:output_dir], "optimization_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"),
      JSON.pretty_generate(results)
    )

    # Save summary as text
    summary_path = File.join(@options[:output_dir], "optimization_summary_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt")
    File.open(summary_path, 'w') do |f|
      f.puts "ADE Optimization Results"
      f.puts "=" * 40
      f.puts "Timestamp: #{results[:timestamp]}"
      f.puts "Examples used: #{@options[:examples] || 'all'}"
      f.puts ""
      f.puts "Test Set Performance:"
      f.puts "  Baseline Accuracy: #{(baseline_test[:accuracy] * 100).round(2)}%"
      f.puts "  Optimized Accuracy: #{(optimized_test[:accuracy] * 100).round(2)}%"
      f.puts "  Improvement: #{((optimized_test[:accuracy] - baseline_test[:accuracy]) * 100).round(2)}%"
      f.puts ""
      f.puts "Validation Set Performance:"
      f.puts "  Baseline Accuracy: #{(baseline_val[:accuracy] * 100).round(2)}%"
      f.puts "  Optimized Accuracy: #{(optimized_val[:accuracy] * 100).round(2)}%"
      f.puts "  Improvement: #{((optimized_val[:accuracy] - baseline_val[:accuracy]) * 100).round(2)}%"
      f.puts ""
      if optimization_result[:cost_analysis]
        f.puts "Cost Analysis:"
        costs = optimization_result[:cost_analysis]
        f.puts "  Total cost: $#{costs[:total_cost].round(4)}"
        f.puts "  Optimizer type: #{costs[:optimizer]}"
        f.puts ""
      end
      if optimization_result[:history]
        history = optimization_result[:history]
        f.puts "Optimization Details:"
        f.puts "  Optimizer: #{history[:optimizer_type]}"
        f.puts "  Training examples: #{history[:training_examples_count]}"
        f.puts "  K-demos: #{history[:k_demos]}"
        f.puts "  Timestamp: #{history[:timestamp]}"
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby run_ade_optimization.rb [options]"

    opts.on("-d", "--data-dir DIR", "Data directory (default: ./data)") do |dir|
      options[:data_dir] = dir
    end

    opts.on("-n", "--examples NUM", Integer, "Number of examples to use (default: all)") do |num|
      options[:examples] = num
    end

    opts.on("-e", "--max-errors NUM", Integer, "Max errors for optimization (default: 3)") do |num|
      options[:max_errors] = num
    end

    opts.on("-o", "--output DIR", "Output directory (default: ./optimization_results)") do |dir|
      options[:output_dir] = dir
    end

    opts.on("--no-download", "Skip downloading dataset") do
      options[:download] = false
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  runner = ADEOptimizationRunner.new(options)
  runner.run
end