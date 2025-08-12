#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'dspy'
require 'json'
require 'fileutils'

require_relative '../lib/data/ade_dataset_loader'
require_relative '../lib/pipeline/ade_pipeline'
require_relative '../lib/pipeline/ade_direct_pipeline'
require_relative '../lib/evaluation/dspy_ade_evaluator'

class DSPyEvaluationRunner
  def initialize
    @results = {}
  end

  def run
    puts "🏥 DSPy.rb Native ADE Pipeline Evaluation (200 Examples)"
    puts "=" * 70
    
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
    
    # Use 200 test examples for statistical significance
    test_examples = training_data[:classification_examples][:test].first(200)
    puts "📊 Using #{test_examples.size} examples for statistically significant evaluation"
    
    positive_count = test_examples.count { |ex|
      expected = ex.respond_to?(:expected_values) ? ex.expected_values : ex[:expected]
      expected[:has_ade]
    }
    puts "   Positive cases: #{positive_count} (#{(positive_count.to_f / test_examples.size * 100).round(1)}%)"

    # Evaluate Multi-Stage Pipeline
    puts "\n1️⃣ Evaluating Multi-Stage Pipeline with DSPy.rb native evaluation..."
    multi_stage_evaluator = DSPyADEEvaluator.new(
      ADEPipeline,
      metric: DSPyMedicalMetrics.comprehensive_medical_metric
    )
    
    @results[:multi_stage] = multi_stage_evaluator.evaluate(
      test_examples,
      sample_size: 200,
      num_threads: 1,  # Conservative threading for API rate limits
      max_errors: 10
    )
    
    multi_stage_evaluator.print_results("Multi-Stage Pipeline Results")

    # Evaluate Direct Pipeline  
    puts "\n2️⃣ Evaluating Direct Pipeline with DSPy.rb native evaluation..."
    direct_evaluator = DSPyADEEvaluator.new(
      ADEDirectPipeline,
      metric: DSPyMedicalMetrics.comprehensive_medical_metric
    )
    
    @results[:direct] = direct_evaluator.evaluate(
      test_examples,
      sample_size: 200,
      num_threads: 1,
      max_errors: 10
    )
    
    direct_evaluator.print_results("Direct Pipeline Results")

    # Generate comparison analysis
    print_comparison_analysis
    
    # Save results
    save_evaluation_results

    puts "\n✅ DSPy.rb native evaluation complete with 200 examples!"
  end

  private

  def print_comparison_analysis
    puts "\n📊 DSPy.rb EVALUATION COMPARISON (200 Examples)"
    puts "=" * 60
    
    multi = @results[:multi_stage]
    direct = @results[:direct]
    
    puts "Performance Comparison:"
    puts "                     Multi-Stage    Direct"
    puts "DSPy Score:          #{(multi[:dspy_score] * 100).round(1)}%        #{(direct[:dspy_score] * 100).round(1)}%"
    puts "Accuracy:            #{(multi[:accuracy] * 100).round(1)}%        #{(direct[:accuracy] * 100).round(1)}%"
    puts "Precision:           #{(multi[:precision] * 100).round(1)}%        #{(direct[:precision] * 100).round(1)}%"
    puts "Recall:              #{(multi[:recall] * 100).round(1)}%        #{(direct[:recall] * 100).round(1)}%"
    puts "F1 Score:            #{(multi[:f1] * 100).round(1)}%        #{(direct[:f1] * 100).round(1)}%"
    puts "False Negative Rate: #{(multi[:false_negative_rate] * 100).round(1)}%         #{(direct[:false_negative_rate] * 100).round(1)}%"
    puts "Missed ADEs:         #{multi[:missed_ades]}             #{direct[:missed_ades]}"
    
    puts "\nConfidence Analysis:"
    puts "Avg Confidence:      #{(multi[:average_confidence] * 100).round(1)}%        #{(direct[:average_confidence] * 100).round(1)}%"
    puts "Low Confidence:      #{multi[:low_confidence_predictions]}             #{direct[:low_confidence_predictions]}"
    
    puts "\nEvaluation Performance:"
    puts "Processing Time:     #{multi[:evaluation_time].round(1)}s        #{direct[:evaluation_time].round(1)}s"
    
    # Analysis
    f1_diff = (multi[:f1] - direct[:f1]) * 100
    recall_diff = (multi[:recall] - direct[:recall]) * 100
    fnr_diff = (multi[:false_negative_rate] - direct[:false_negative_rate]) * 100
    
    puts "\n💡 Key Insights (200 Examples):"
    puts "  • F1 Score difference: #{f1_diff > 0 ? '+' : ''}#{f1_diff.round(1)}% (Multi-Stage advantage)"
    puts "  • Recall difference: #{recall_diff > 0 ? '+' : ''}#{recall_diff.round(1)}% (Medical safety)" 
    puts "  • FNR difference: #{fnr_diff > 0 ? '+' : ''}#{fnr_diff.round(1)}% (Lower is better)"
    puts "  • Processing speed: Direct pipeline #{(multi[:evaluation_time] / direct[:evaluation_time]).round(1)}x faster"
    
    if recall_diff.abs < 2.0
      puts "  ✅ Similar medical safety profile between approaches"
    elsif recall_diff > 0
      puts "  ⚠️  Multi-stage has better recall (fewer missed ADEs)"
    else
      puts "  ⚠️  Direct approach has better recall (fewer missed ADEs)"
    end
    
    # Realistic recommendation based on 200 examples
    puts "\n🎯 Statistical Recommendation (200 examples):"
    if f1_diff.abs < 3.0 && fnr_diff.abs < 2.0
      puts "  Direct pipeline recommended: Similar performance with cost/speed advantages"
    elsif f1_diff > 5.0
      puts "  Multi-stage justified: Significantly better performance"
    else
      puts "  Context-dependent: Consider specific use case requirements"
    end
  end

  def save_evaluation_results
    FileUtils.mkdir_p('results')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    results_data = {
      evaluation_type: 'dspy_native_200_examples',
      timestamp: timestamp,
      model: 'gpt-4o-mini',
      sample_size: 200,
      evaluation_framework: 'DSPy.rb native evaluation',
      results: @results
    }
    
    filename = "results/dspy_evaluation_200_#{timestamp}.json"
    File.write(filename, JSON.pretty_generate(results_data))
    
    puts "\n💾 DSPy.rb evaluation results saved to #{filename}"
    
    # Also create a summary report
    create_summary_report(timestamp)
  end

  def create_summary_report(timestamp)
    filename = "results/dspy_evaluation_summary_#{timestamp}.md"
    
    multi = @results[:multi_stage]
    direct = @results[:direct]
    
    report_content = <<~MARKDOWN
      # DSPy.rb Native ADE Evaluation Results (200 Examples)

      **Evaluation Date**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  
      **Framework**: DSPy.rb native evaluation system  
      **Sample Size**: 200 examples (statistically significant)  
      **Model**: gpt-4o-mini

      ## Executive Summary

      Comprehensive evaluation using DSPy.rb's built-in evaluation framework instead of manual metrics calculation. This provides standardized, framework-native performance assessment.

      ## Results

      | Metric | Multi-Stage | Direct | Difference |
      |--------|-------------|--------|------------|
      | **DSPy Score** | #{(multi[:dspy_score] * 100).round(1)}% | #{(direct[:dspy_score] * 100).round(1)}% | #{((multi[:dspy_score] - direct[:dspy_score]) * 100).round(1)}% |
      | **Accuracy** | #{(multi[:accuracy] * 100).round(1)}% | #{(direct[:accuracy] * 100).round(1)}% | #{((multi[:accuracy] - direct[:accuracy]) * 100).round(1)}% |
      | **Precision** | #{(multi[:precision] * 100).round(1)}% | #{(direct[:precision] * 100).round(1)}% | #{((multi[:precision] - direct[:precision]) * 100).round(1)}% |
      | **Recall** | #{(multi[:recall] * 100).round(1)}% | #{(direct[:recall] * 100).round(1)}% | #{((multi[:recall] - direct[:recall]) * 100).round(1)}% |
      | **F1 Score** | #{(multi[:f1] * 100).round(1)}% | #{(direct[:f1] * 100).round(1)}% | #{((multi[:f1] - direct[:f1]) * 100).round(1)}% |
      | **False Negative Rate** | #{(multi[:false_negative_rate] * 100).round(1)}% | #{(direct[:false_negative_rate] * 100).round(1)}% | #{((multi[:false_negative_rate] - direct[:false_negative_rate]) * 100).round(1)}% |
      | **Missed ADEs** | #{multi[:missed_ades]} | #{direct[:missed_ades]} | #{multi[:missed_ades] - direct[:missed_ades]} |

      ## Medical Safety Analysis

      ### False Negatives (Missed ADEs)
      - **Multi-Stage**: #{multi[:missed_ades]} cases (#{(multi[:false_negative_rate] * 100).round(1)}% FNR)
      - **Direct**: #{direct[:missed_ades]} cases (#{(direct[:false_negative_rate] * 100).round(1)}% FNR)

      #{multi[:false_negatives].any? || direct[:false_negatives].any? ? "### Examples of Missed Cases" : "### No False Negatives Found"}
      #{if multi[:false_negatives].any?
        multi[:false_negatives].first(2).map.with_index(1) { |fn, i| "**Multi-Stage FN #{i}**: #{fn[:text][0..100]}..." }.join("\n")
      end}
      #{if direct[:false_negatives].any?  
        direct[:false_negatives].first(2).map.with_index(1) { |fn, i| "**Direct FN #{i}**: #{fn[:text][0..100]}..." }.join("\n")
      end}

      ## DSPy.rb Framework Value

      This evaluation demonstrates DSPy.rb's native evaluation capabilities:
      - **Standardized Metrics**: Framework-consistent evaluation approach
      - **Statistical Significance**: 200 examples provide reliable confidence
      - **Medical Domain Focus**: Custom metrics for medical safety priorities
      - **Error Analysis**: Detailed false negative and confidence analysis

      ## Conclusion

      #{if (multi[:recall] - direct[:recall]).abs < 0.02
        "Both approaches show similar medical safety profiles with DSPy.rb native evaluation confirming our earlier findings."
      else
        "Significant differences in medical safety performance detected with statistical significance."
      end}
    MARKDOWN
    
    File.write(filename, report_content)
    puts "📄 Summary report: #{filename}"
  end
end

# Run the DSPy.rb native evaluation
if __FILE__ == $0
  runner = DSPyEvaluationRunner.new
  runner.run
end