#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'dspy'
require 'json'
require 'fileutils'

require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/optimization/comprehensive_optimizer'

class ComprehensiveComparisonRunner
  def initialize
    @results = nil
  end

  def run
    puts "🏥 DSPy.rb ADE Pipeline Comprehensive Comparison"
    puts "=" * 60
    
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
    
    puts "✅ Dataset loaded:"
    puts "  Training: #{training_data[:classification_examples][:train].size} examples"
    puts "  Validation: #{training_data[:classification_examples][:val].size} examples" 
    puts "  Test: #{training_data[:classification_examples][:test].size} examples"

    # Run comprehensive comparison
    optimizer = ComprehensiveOptimizer.new(
      config: {
        test_sample_size: 25,  # Reasonable sample for comparison
        max_examples_per_optimizer: 8,  # Conservative for quick testing
        display_progress: true
      }
    )

    puts "\n🚀 Starting comprehensive comparison..."
    @results = optimizer.comprehensive_comparison(training_data)

    if @results[:error]
      puts "❌ Comparison failed: #{@results[:error]}"
      return
    end

    # Display results
    display_results
    
    # Save results
    save_results
    
    # Generate summary report
    generate_summary_report

    puts "\n✅ Comprehensive comparison complete!"
  end

  private

  def display_results
    puts "\n📊 COMPREHENSIVE COMPARISON RESULTS"
    puts "=" * 50

    approaches = @results[:approaches]
    
    # Display each approach
    approaches.each do |name, data|
      next if data[:error]
      
      display_name = name.to_s.split('_').map(&:capitalize).join(' ')
      puts "\n#{display_name}:"
      
      classification = data[:classification]
      performance = data[:performance]
      
      puts "  Accuracy:  #{(classification[:accuracy] * 100).round(1)}%"
      puts "  Precision: #{(classification[:precision] * 100).round(1)}%"  
      puts "  Recall:    #{(classification[:recall] * 100).round(1)}%"
      puts "  F1 Score:  #{(classification[:f1] * 100).round(1)}%"
      puts "  API Calls: #{performance[:total_api_calls]} total (#{performance[:api_calls_per_prediction].round(1)} per prediction)"
      puts "  Cost:      $#{performance[:estimated_cost_usd]}"
      puts "  Errors:    #{performance[:processing_errors]}"
      puts "  Avg Time:  #{performance[:avg_processing_time]}s"
      
      # Show optimization improvements if available
      if data[:improvements] && !data[:improvements][:error]
        improvements = data[:improvements]
        f1_change = improvements[:f1_improvement][:absolute_change]
        puts "  F1 Change: #{f1_change > 0 ? '+' : ''}#{f1_change}%"
      end
    end

    # Display analysis
    if @results[:comparison] && !@results[:comparison][:error]
      analysis = @results[:comparison]
      puts "\n💡 KEY INSIGHTS"
      puts "-" * 20
      
      if analysis[:cost_efficiency]
        cost = analysis[:cost_efficiency]
        puts "Cost Efficiency:"
        puts "  • Multi-stage vs Direct: #{cost[:api_call_ratio]}x more API calls"
        puts "  • Cost savings with Direct: #{cost[:cost_savings_pct]}%"
        puts "  • Performance trade-off: #{cost[:performance_trade_off_pct]}%"
      end
      
      if analysis[:optimization_effectiveness]
        opt = analysis[:optimization_effectiveness] 
        puts "Optimization Effectiveness:"
        puts "  • Baseline F1: #{opt[:baseline_f1]}%"
        puts "  • Optimized F1: #{opt[:optimized_f1]}%"
        puts "  • Improvement: #{opt[:improvement_pct]}%"
        puts "  • Worthwhile: #{opt[:optimization_worthwhile] ? 'Yes' : 'No'}"
      end
    end

    # Display recommendations
    if @results[:recommendations] && @results[:recommendations].any?
      puts "\n🎯 RECOMMENDATIONS"
      puts "-" * 20
      
      @results[:recommendations].each_with_index do |rec, i|
        puts "#{i + 1}. #{rec[:category]}: #{rec[:recommendation]}"
        puts "   Reasoning: #{rec[:reasoning]}"
        puts "   Confidence: #{rec[:confidence]}"
        puts
      end
    end
  end

  def save_results
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    # Save detailed JSON results
    json_filename = "results/comprehensive_comparison_#{timestamp}.json"
    File.write(json_filename, JSON.pretty_generate(@results))
    puts "\n💾 Detailed results saved to #{json_filename}"
  end

  def generate_summary_report
    return unless @results && !@results[:error]
    
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    report_filename = "results/comparison_summary_#{timestamp}.md"
    
    File.write(report_filename, build_markdown_report)
    puts "📄 Summary report saved to #{report_filename}"
  end

  def build_markdown_report
    <<~MARKDOWN
      # DSPy.rb ADE Pipeline Comprehensive Comparison

      **Generated**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  
      **Test Sample Size**: #{@results[:test_sample_size]} examples  
      **Model**: gpt-4o-mini

      ## Executive Summary

      This comparison evaluates different ADE (Adverse Drug Event) detection approaches using DSPy.rb:
      1. **Multi-Stage Pipeline** (3 API calls) - Drug extraction → Effect extraction → Classification  
      2. **Direct Pipeline** (1 API call) - End-to-end classification with reasoning
      3. **Optimized Direct Pipeline** - Direct approach enhanced with SimpleOptimizer

      ## Results Summary

      #{generate_results_table}

      ## Key Findings

      #{generate_key_findings}

      ## Recommendations

      #{generate_recommendations_section}

      ## Technical Implementation

      This comparison demonstrates DSPy.rb's key strengths:
      - **Architectural Flexibility**: Easy to implement and compare different approaches
      - **Optimization Integration**: Seamless SimpleOptimizer integration for performance improvement  
      - **Cost Awareness**: Built-in tracking of API calls and estimated costs
      - **Production Readiness**: Proper error handling, confidence intervals, and comprehensive evaluation

      ## Conclusion

      DSPy.rb enables rapid experimentation with ML architectures while providing the tools needed for production deployment. The framework's flexibility allows developers to optimize for different priorities (cost vs performance) and easily compare approaches to make informed decisions.
    MARKDOWN
  end

  def generate_results_table
    return "No results available" unless @results[:approaches]

    table = "| Approach | F1 Score | API Calls | Cost | Errors |\n"
    table += "|----------|----------|-----------|------|--------|\n"
    
    @results[:approaches].each do |name, data|
      next if data[:error]
      
      display_name = name.to_s.split('_').map(&:capitalize).join(' ')
      f1 = (data[:classification][:f1] * 100).round(1)
      api_calls = data[:performance][:total_api_calls]
      cost = "$#{data[:performance][:estimated_cost_usd]}"
      errors = data[:performance][:processing_errors]
      
      table += "| #{display_name} | #{f1}% | #{api_calls} | #{cost} | #{errors} |\n"
    end
    
    table
  end

  def generate_key_findings
    return "Analysis not available" unless @results[:comparison] && !@results[:comparison][:error]

    findings = []
    analysis = @results[:comparison]
    
    if analysis[:cost_efficiency]
      cost = analysis[:cost_efficiency]
      findings << "- **Cost Efficiency**: Direct pipeline uses #{cost[:api_call_ratio]}x fewer API calls, saving #{cost[:cost_savings_pct]}% in costs"
    end
    
    if analysis[:optimization_effectiveness]
      opt = analysis[:optimization_effectiveness]
      findings << "- **Optimization Impact**: SimpleOptimizer improved F1 score by #{opt[:improvement_pct]}% (#{opt[:baseline_f1]}% → #{opt[:optimized_f1]}%)"
    end
    
    findings.empty? ? "Key findings not available" : findings.join("\n")
  end

  def generate_recommendations_section
    return "No recommendations available" unless @results[:recommendations] && @results[:recommendations].any?

    recs = @results[:recommendations].map.with_index(1) do |rec, i|
      "#{i}. **#{rec[:category]}**: #{rec[:recommendation]}  \n   *#{rec[:reasoning]}* (Confidence: #{rec[:confidence]})"
    end.join("\n\n")
    
    recs
  end
end

# Run the comprehensive comparison
if __FILE__ == $0
  runner = ComprehensiveComparisonRunner.new
  runner.run
end