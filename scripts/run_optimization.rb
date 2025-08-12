#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'
require 'fileutils'
require 'dotenv/load'
require 'dspy'

require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/optimization/pipeline_optimizer'

class OptimizationRunner
  def initialize(options = {})
    @options = {
      optimizer: 'simple',  # 'simple' or 'miprov2' or 'both'
      data_size: 100,       # Number of examples to use
      output_dir: 'results'
    }.merge(options)

    FileUtils.mkdir_p(@options[:output_dir])
  end

  def run
    puts "🏥 ADE Pipeline Optimization"
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

    # Load and prepare training data
    puts "\n📥 Loading ADE dataset..."
    loader = AdeDatasetLoader.new
    training_data = loader.prepare_training_data
    
    # Limit dataset size if requested
    if @options[:data_size] < training_data[:classification_examples][:train].size
      puts "📌 Limiting dataset to #{@options[:data_size]} examples per split"
      
      %i[train val test].each do |split|
        original_size = training_data[:classification_examples][split].size
        limit = (@options[:data_size] * get_split_ratio(split)).to_i
        training_data[:classification_examples][split] = training_data[:classification_examples][split].first(limit)
        puts "  #{split.capitalize}: #{original_size} → #{training_data[:classification_examples][split].size}"
      end
    end

    # Initialize optimizer
    optimizer = PipelineOptimizer.new(config: {
      max_errors: 3,
      display_progress: true,
      optimization_mode: 'medical_safety'
    })

    results = {}

    # Run optimizations based on options
    case @options[:optimizer]
    when 'simple'
      results[:simple_optimizer] = optimizer.optimize_with_simple_optimizer(training_data)
    when 'miprov2'  
      results[:miprov2] = optimizer.optimize_with_miprov2(training_data)
    when 'both'
      puts "🔄 Running both optimizers for comparison..."
      results[:simple_optimizer] = optimizer.optimize_with_simple_optimizer(training_data)
      
      puts "\n" + "=" * 60
      
      results[:miprov2] = optimizer.optimize_with_miprov2(training_data)
    end

    # Print results summary
    print_results_summary(results)
    
    # Save detailed results
    save_results(results, training_data)
    
    puts "\n✅ Optimization complete! Results saved to #{@options[:output_dir]}/"
  end

  private

  def get_split_ratio(split)
    case split
    when :train then 0.7
    when :val then 0.15
    when :test then 0.15
    else 0.1
    end
  end

  def print_results_summary(results)
    puts "\n" + "=" * 60
    puts "OPTIMIZATION RESULTS SUMMARY"
    puts "=" * 60

    results.each do |optimizer_name, result|
      next if result[:error]
      
      puts "\n🚀 #{optimizer_name.to_s.upcase.gsub('_', ' ')}"
      puts "-" * 40
      
      baseline = result[:baseline]
      optimized = result[:optimized]
      improvements = result[:improvements]
      
      # Print metrics comparison
      puts "Performance Improvements:"
      
      %i[drug_extraction effect_extraction classification].each do |component|
        comp_name = component.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
        baseline_f1 = (baseline[component][:f1] * 100).round(1)
        optimized_f1 = (optimized[component][:f1] * 100).round(1)
        improvement = improvements[component][:improvement_pct]
        
        puts "  #{comp_name}:"
        puts "    Baseline F1: #{baseline_f1}%"
        puts "    Optimized F1: #{optimized_f1}%"
        puts "    Improvement: #{improvement > 0 ? '+' : ''}#{improvement}%"
      end
      
      # Safety metrics
      baseline_fnr = (baseline[:safety][:false_negative_rate] * 100).round(1)
      optimized_fnr = (optimized[:safety][:false_negative_rate] * 100).round(1)
      fnr_reduction = improvements[:safety][:fnr_reduction]
      
      puts "  Medical Safety:"
      puts "    Baseline False Negative Rate: #{baseline_fnr}%"
      puts "    Optimized False Negative Rate: #{optimized_fnr}%"
      puts "    FNR Reduction: #{fnr_reduction > 0 ? '-' : '+'}#{fnr_reduction.abs}% #{fnr_reduction > 0 ? '✅' : '❌'}"
      
      # Cost analysis
      if result[:cost_analysis]
        cost = result[:cost_analysis]
        puts "  Cost Analysis:"
        puts "    Method: #{cost[:method]}"
        puts "    Estimated API calls: #{cost[:estimated_api_calls]}"
        puts "    Estimated cost: $#{cost[:estimated_cost].round(4)}"
      end
    end

    # Compare optimizers if both were run
    if results[:simple_optimizer] && results[:miprov2] && !results[:simple_optimizer][:error] && !results[:miprov2][:error]
      puts "\n🆚 OPTIMIZER COMPARISON"
      puts "-" * 30
      
      simple_f1 = results[:simple_optimizer][:optimized][:classification][:f1]
      mipro_f1 = results[:miprov2][:optimized][:classification][:f1]
      
      simple_fnr = results[:simple_optimizer][:optimized][:safety][:false_negative_rate]
      mipro_fnr = results[:miprov2][:optimized][:safety][:false_negative_rate]
      
      puts "Classification F1:"
      puts "  SimpleOptimizer: #{(simple_f1 * 100).round(1)}%"
      puts "  MIPROv2: #{(mipro_f1 * 100).round(1)}%"
      puts "  Winner: #{mipro_f1 > simple_f1 ? 'MIPROv2' : 'SimpleOptimizer'} 🏆"
      
      puts "False Negative Rate (lower is better):"
      puts "  SimpleOptimizer: #{(simple_fnr * 100).round(1)}%"
      puts "  MIPROv2: #{(mipro_fnr * 100).round(1)}%"
      puts "  Better for safety: #{mipro_fnr < simple_fnr ? 'MIPROv2' : 'SimpleOptimizer'} 🩺"
    end
  end

  def save_results(results, training_data)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    results_dir = File.join(@options[:output_dir], timestamp)
    FileUtils.mkdir_p(results_dir)

    # Save comprehensive results
    full_results = {
      timestamp: timestamp,
      configuration: @options,
      dataset_info: {
        train_size: training_data[:classification_examples][:train].size,
        val_size: training_data[:classification_examples][:val].size,
        test_size: training_data[:classification_examples][:test].size,
        extraction_examples: {
          drug_extraction: training_data[:extraction_examples][:drug_extraction].size,
          effect_extraction: training_data[:extraction_examples][:effect_extraction].size
        }
      },
      results: results
    }

    # Save JSON results
    json_file = File.join(results_dir, 'optimization_results.json')
    File.write(json_file, JSON.pretty_generate(full_results))

    # Save human-readable summary
    summary_file = File.join(results_dir, 'optimization_summary.txt')
    File.open(summary_file, 'w') do |f|
      f.puts "ADE Pipeline Optimization Summary"
      f.puts "=" * 40
      f.puts "Timestamp: #{timestamp}"
      f.puts "Configuration: #{@options.inspect}"
      f.puts ""
      
      results.each do |optimizer_name, result|
        next if result[:error]
        
        f.puts "#{optimizer_name.to_s.upcase}:"
        f.puts "  Classification F1: #{(result[:optimized][:classification][:f1] * 100).round(1)}%"
        f.puts "  False Negative Rate: #{(result[:optimized][:safety][:false_negative_rate] * 100).round(1)}%"
        f.puts "  Cost: $#{result[:cost_analysis][:estimated_cost].round(4)}"
        f.puts ""
      end
    end

    puts "\n💾 Results saved:"
    puts "  📊 JSON: #{json_file}"
    puts "  📝 Summary: #{summary_file}"
  end
end

# Command line interface
if __FILE__ == $0
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/run_optimization.rb [options]"

    opts.on("-o", "--optimizer TYPE", ["simple", "miprov2", "both"], 
            "Optimizer to use: simple, miprov2, or both (default: simple)") do |opt|
      options[:optimizer] = opt
    end

    opts.on("-n", "--size NUM", Integer, 
            "Number of examples to use (default: 100)") do |num|
      options[:data_size] = num
    end

    opts.on("--output DIR", 
            "Output directory (default: results)") do |dir|
      options[:output_dir] = dir
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  runner = OptimizationRunner.new(options)
  runner.run
end