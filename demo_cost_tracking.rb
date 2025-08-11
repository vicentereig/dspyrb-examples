#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to show cost tracking capabilities for ADE optimization

require_relative 'lib/baseline_predictor'
require_relative 'lib/ade_optimizer'  
require_relative 'lib/vcr_cost_analyzer'

puts "🏥 ADE Optimization Cost Tracking Demo"
puts "=" * 50

# 1. Demonstrate BaselinePredictor cost tracking
puts "\n📊 1. BaselinePredictor Cost Tracking"
puts "-" * 30

predictor = BaselinePredictor.new
puts "Initial cost summary:"
puts predictor.cost_summary.inspect

# Simulate some predictions with mock token usage
test_inputs = [
  {
    patient_report: "Patient reports mild nausea after taking medication",
    medications: ["test_drug_a"],
    symptoms: "mild nausea"
  },
  {
    patient_report: "Patient experienced severe allergic reaction",
    medications: ["penicillin"],
    symptoms: "severe allergic reaction"
  },
  {
    patient_report: "No adverse effects reported",
    medications: ["safe_medication"],
    symptoms: "none"
  }
]

puts "\nMaking #{test_inputs.size} predictions..."
test_inputs.each_with_index do |input, i|
  result = predictor.predict(input)
  puts "  Prediction #{i+1}: #{result[:ade_status]} (confidence: #{result[:confidence]})"
end

puts "\nFinal cost summary after predictions:"
cost_summary = predictor.cost_summary
puts "  Total cost: $#{cost_summary[:total_cost].round(6)}"
puts "  Requests: #{cost_summary[:requests]}"
puts "  Total tokens: #{cost_summary[:tokens][:total_tokens]}"
puts "  Model: #{cost_summary[:model]}"

# 2. Demonstrate ADEOptimizer cost tracking
puts "\n🔧 2. ADEOptimizer Cost Tracking"
puts "-" * 30

optimizer = ADEOptimizer.new
puts "Optimization cost summary:"
opt_cost = optimizer.optimization_cost_summary
puts "  Total optimization cost: $#{opt_cost[:total_cost]}"
puts "  Baseline evaluation cost: $#{opt_cost[:baseline_cost]}"
puts "  Optimization cost: $#{opt_cost[:optimization_cost]}"
puts "  Pricing info: #{opt_cost[:gpt_4o_mini_pricing]}"

# 3. Demonstrate VCR Cost Analysis
puts "\n📼 3. VCR Cost Analysis from Recorded Cassettes"
puts "-" * 45

analyzer = VCRCostAnalyzer.new
puts "Analyzing VCR cassettes for actual costs..."

# Analyze specific cassette if it exists
token_usage_cassette = 'spec/fixtures/vcr_cassettes/ade_reproducibility/token_usage.yml'
if File.exist?(token_usage_cassette)
  puts "\nAnalyzing token_usage cassette:"
  cassette_analysis = analyzer.analyze_cassette(token_usage_cassette)
  puts "  Requests: #{cassette_analysis[:requests]}"
  puts "  Total tokens: #{cassette_analysis[:total_tokens]}"
  puts "  Input tokens: #{cassette_analysis[:total_input_tokens]}"  
  puts "  Output tokens: #{cassette_analysis[:total_output_tokens]}"
  puts "  Total cost: $#{cassette_analysis[:total_cost]}"
  puts "  Cost per request: $#{cassette_analysis[:cost_per_request]}"
else
  puts "  Token usage cassette not found - skipping detailed analysis"
end

# Comprehensive ADE cassette analysis
puts "\nComprehensive ADE cassette analysis:"
ade_analysis = analyzer.analyze_ade_cassettes
summary = ade_analysis[:summary]

puts "  Total cassettes analyzed: #{summary[:cassettes_analyzed]}"
puts "  Total requests: #{summary[:requests]}"
puts "  Total tokens: #{summary[:total_tokens]}"
puts "  Total cost: $#{summary[:total_cost].round(6)}"
puts "  Model: #{summary[:model]}"

if summary[:requests] > 0
  puts "\n  Cost breakdown:"
  breakdown = ade_analysis[:cost_breakdown]
  puts "    Input cost: $#{breakdown[:input_cost]}"
  puts "    Output cost: $#{breakdown[:output_cost]}"
  puts "    Avg tokens/request: #{breakdown[:avg_tokens_per_request]}"
  puts "    Cost per 1K tokens: $#{breakdown[:cost_per_1k_tokens]}"

  puts "\n  By cassette details:"
  ade_analysis[:by_cassette].each do |cassette, data|
    puts "    #{cassette}: #{data[:requests]} requests, $#{data[:total_cost].round(6)}"
  end
end

# 4. Optimization Phase Cost Analysis
puts "\n🚀 4. Optimization Phase Cost Analysis"
puts "-" * 35

phase_analysis = analyzer.optimization_phase_costs
puts "Phase cost breakdown:"
phase_analysis[:by_phase].each do |phase, data|
  puts "  #{phase.capitalize}: $#{data[:total_cost].round(6)} (#{data[:requests]} requests)"
  puts "    Cassettes: #{data[:cassettes].join(', ')}" unless data[:cassettes].empty?
end

puts "\nTotal optimization cost: $#{phase_analysis[:total_optimization_cost].round(6)}"

puts "\n💡 Cost Optimization Recommendations:"
phase_analysis[:recommendations].each do |rec|
  puts "  • #{rec}"
end

# 5. Cost Per Use Case Analysis
puts "\n💰 5. Cost-Effectiveness Analysis"
puts "-" * 30

if summary[:requests] > 0 && summary[:total_cost] > 0
  cost_per_prediction = summary[:total_cost] / summary[:requests]
  puts "Cost per prediction: $#{cost_per_prediction.round(6)}"
  
  # Medical AI context
  predictions_per_dollar = 1.0 / cost_per_prediction
  puts "Predictions per $1: #{predictions_per_dollar.round(0)}"
  
  # Annual cost estimates
  daily_predictions = 100
  annual_cost = cost_per_prediction * daily_predictions * 365
  puts "\nEstimated costs for medical practice:"
  puts "  100 predictions/day: $#{annual_cost.round(2)}/year"
  
  monthly_cost = annual_cost / 12
  puts "  Monthly cost: $#{monthly_cost.round(2)}"
  
  if monthly_cost < 50
    puts "  💚 Very cost-effective for medical AI applications"
  elsif monthly_cost < 200
    puts "  💛 Reasonable cost for medical AI applications"
  else
    puts "  🔴 Consider optimization to reduce costs"
  end
else
  puts "No recorded API usage found in cassettes - run some tests first!"
end

puts "\n✅ Cost tracking demo completed!"
puts "\nNext steps:"
puts "• Run optimization tests to generate cost data"
puts "• Monitor costs during development"
puts "• Use cost insights to optimize LLM usage"