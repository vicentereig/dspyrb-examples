# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/baseline_predictor'
require_relative '../../lib/ade_optimizer'
require_relative '../../lib/vcr_cost_analyzer'

RSpec.describe "Cost Tracking" do
  describe BaselinePredictor do
    let(:predictor) { BaselinePredictor.new }

    before do
      predictor.reset_cost_tracking
    end

    describe "#cost_summary" do
      it "initializes with zero costs" do
        cost_summary = predictor.cost_summary
        
        expect(cost_summary[:total_cost]).to eq(0.0)
        expect(cost_summary[:requests]).to eq(0)
        expect(cost_summary[:model]).to eq('gpt-4o-mini')
        expect(cost_summary[:tokens]).to include(
          total_tokens: 0,
          input_tokens: 0,
          output_tokens: 0
        )
      end

      it "includes pricing information" do
        cost_summary = predictor.cost_summary
        
        expect(cost_summary[:cost_per_1k_input]).to eq(0.00015)
        expect(cost_summary[:cost_per_1k_output]).to eq(0.0006)
      end
    end

    describe "#update_actual_token_usage" do
      it "processes OpenAI usage data correctly" do
        usage_data = {
          'prompt_tokens' => 100,
          'completion_tokens' => 50,
          'total_tokens' => 150
        }

        predictor.send(:update_actual_token_usage, usage_data)
        
        token_usage = predictor.token_usage
        expect(token_usage[:input_tokens]).to eq(100)
        expect(token_usage[:output_tokens]).to eq(50)
        expect(token_usage[:total_tokens]).to eq(150)

        cost_summary = predictor.cost_summary
        expected_cost = (100 / 1000.0 * 0.00015) + (50 / 1000.0 * 0.0006)
        expect(cost_summary[:total_cost]).to be_within(0.000001).of(expected_cost)
        expect(cost_summary[:requests]).to eq(1)
      end

      it "handles symbol keys in usage data" do
        usage_data = {
          prompt_tokens: 200,
          completion_tokens: 75,
          total_tokens: 275
        }

        predictor.send(:update_actual_token_usage, usage_data)
        
        token_usage = predictor.token_usage
        expect(token_usage[:input_tokens]).to eq(200)
        expect(token_usage[:output_tokens]).to eq(75)
        expect(token_usage[:total_tokens]).to eq(275)
      end
    end

    describe "cost calculation accuracy" do
      it "calculates costs correctly for gpt-4o-mini pricing" do
        # Test with known values
        usage_data = {
          'prompt_tokens' => 1000,
          'completion_tokens' => 500,
          'total_tokens' => 1500
        }

        predictor.send(:update_actual_token_usage, usage_data)
        
        cost_summary = predictor.cost_summary
        
        # Manual calculation: 
        # Input: 1000 tokens * $0.00015/1K = $0.00015
        # Output: 500 tokens * $0.0006/1K = $0.0003
        # Total: $0.00045
        expected_total_cost = 0.00045
        
        expect(cost_summary[:total_cost]).to be_within(0.000001).of(expected_total_cost)
      end
    end

    describe "#reset_cost_tracking" do
      it "resets both token usage and cost tracking" do
        # Add some usage first
        predictor.send(:update_actual_token_usage, {
          'prompt_tokens' => 100,
          'completion_tokens' => 50,
          'total_tokens' => 150
        })

        # Verify it was recorded
        expect(predictor.token_usage[:total_tokens]).to eq(150)
        expect(predictor.cost_summary[:total_cost]).to be > 0

        # Reset
        predictor.reset_cost_tracking

        # Verify reset
        expect(predictor.token_usage[:total_tokens]).to eq(0)
        expect(predictor.cost_summary[:total_cost]).to eq(0.0)
        expect(predictor.cost_summary[:requests]).to eq(0)
      end
    end
  end

  describe ADEOptimizer do
    let(:optimizer) { ADEOptimizer.new }

    describe "#optimization_cost_summary" do
      it "provides cost breakdown for optimization" do
        cost_summary = optimizer.optimization_cost_summary
        
        expect(cost_summary).to include(
          :total_cost,
          :baseline_cost,
          :optimization_cost,
          :gpt_4o_mini_pricing
        )
        
        expect(cost_summary[:gpt_4o_mini_pricing]).to include(
          input_per_1k: 0.00015,
          output_per_1k: 0.0006
        )
      end
    end

    describe "#generate_cost_analysis" do
      it "generates detailed cost analysis for optimization methods" do
        analysis = optimizer.send(:generate_cost_analysis, 'SimpleOptimizer')
        
        expect(analysis).to include(
          :optimizer,
          :total_cost,
          :baseline_evaluation_cost,
          :optimization_cost,
          :model,
          :cost_breakdown
        )
        
        expect(analysis[:optimizer]).to eq('SimpleOptimizer')
        expect(analysis[:model]).to eq('gpt-4o-mini')
      end
    end
  end

  describe VCRCostAnalyzer do
    let(:analyzer) { VCRCostAnalyzer.new('spec/fixtures/vcr_cassettes') }

    describe "#analyze_cassette" do
      let(:token_usage_cassette) { 'spec/fixtures/vcr_cassettes/ade_reproducibility/token_usage.yml' }

      it "extracts cost information from VCR cassette", :vcr do
        skip "VCR cassette file not found" unless File.exist?(token_usage_cassette)
        
        analysis = analyzer.analyze_cassette(token_usage_cassette)
        
        expect(analysis).to include(
          :total_cost,
          :total_tokens,
          :total_input_tokens,
          :total_output_tokens,
          :requests,
          :cost_per_request
        )
        
        # Should have positive values if cassette contains real interactions
        if analysis[:requests] > 0
          expect(analysis[:total_cost]).to be > 0
          expect(analysis[:total_tokens]).to be > 0
        end
      end

      it "handles non-existent cassette gracefully" do
        analysis = analyzer.analyze_cassette('non_existent.yml')
        expect(analysis[:error]).to include("Cassette not found")
      end
    end

    describe "#analyze_ade_cassettes" do
      it "provides comprehensive cost analysis across all ADE cassettes" do
        analysis = analyzer.analyze_ade_cassettes
        
        expect(analysis).to include(:summary, :by_cassette, :cost_breakdown)
        
        summary = analysis[:summary]
        expect(summary).to include(
          :total_cost,
          :total_tokens,
          :requests,
          :cassettes_analyzed,
          :model
        )
        
        expect(summary[:model]).to eq('gpt-4o-mini')
      end
    end

    describe "#optimization_phase_costs" do
      it "breaks down costs by optimization phases" do
        phase_analysis = analyzer.optimization_phase_costs
        
        expect(phase_analysis).to include(:by_phase, :total_optimization_cost, :recommendations)
        
        by_phase = phase_analysis[:by_phase]
        expect(by_phase).to include('baseline', 'optimization', 'integration', 'reproducibility')
        
        # Each phase should have cost information
        by_phase.values.each do |phase_data|
          expect(phase_data).to include(:total_cost, :requests, :cassettes, :cost_per_request)
        end
      end

      it "provides cost optimization recommendations" do
        phase_analysis = analyzer.optimization_phase_costs
        recommendations = phase_analysis[:recommendations]
        
        expect(recommendations).to be_an(Array)
        expect(recommendations).not_to be_empty
        expect(recommendations.last).to include("Total development cost so far")
      end
    end
  end

  describe "Integration between BaselinePredictor and cost analysis" do
    it "provides realistic cost estimates for ADE prediction tasks" do
      predictor = BaselinePredictor.new
      analyzer = VCRCostAnalyzer.new

      # Test realistic token usage scenario
      # Typical ADE prediction might use ~700-800 tokens per request
      realistic_usage = {
        'prompt_tokens' => 729,
        'completion_tokens' => 75,
        'total_tokens' => 804
      }

      predictor.send(:update_actual_token_usage, realistic_usage)
      
      cost_summary = predictor.cost_summary
      
      # Cost should be reasonable for medical AI application
      expect(cost_summary[:total_cost]).to be_between(0.0001, 0.01)
      
      # Should provide good value per prediction
      cost_per_prediction = cost_summary[:total_cost]
      expect(cost_per_prediction).to be < 0.001  # Less than $0.001 per prediction
    end
  end
end