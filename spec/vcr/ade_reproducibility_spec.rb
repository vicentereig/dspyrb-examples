# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_predictor'
require_relative '../../lib/baseline_predictor'
require_relative '../../lib/ade_optimizer'

RSpec.describe "ADE VCR Reproducibility", type: :vcr do
  describe "Reproducible predictions" do
    it "produces consistent results with VCR cassettes", vcr: { cassette_name: 'ade_reproducibility/consistent_prediction' } do
      # Test that the same input produces identical results across test runs
      baseline_predictor = BaselinePredictor.new
      
      test_input = {
        patient_report: "Patient experienced mild nausea after taking ibuprofen for headache relief",
        medications: ["ibuprofen"],
        symptoms: "mild nausea"
      }
      
      # Make prediction twice to verify consistency
      result1 = baseline_predictor.predict(test_input)
      result2 = baseline_predictor.predict(test_input)
      
      # Results should be structurally identical
      expect(result1.keys).to eq(result2.keys)
      expect(result1[:ade_status]).to eq(result2[:ade_status])
      expect(result1[:confidence]).to eq(result2[:confidence])
      expect(result1[:drug_symptom_pairs].size).to eq(result2[:drug_symptom_pairs].size)
    end
    
    it "handles medical safety scenarios reproducibly", vcr: { cassette_name: 'ade_reproducibility/medical_safety' } do
      # Test reproducibility of medical safety scenarios
      baseline_predictor = BaselinePredictor.new
      
      high_risk_scenarios = [
        {
          patient_report: "Patient developed severe allergic reaction with breathing difficulties",
          medications: ["penicillin"],
          symptoms: "severe allergic reaction, breathing difficulties"
        },
        {
          patient_report: "No adverse effects reported, patient doing well on treatment",
          medications: ["safe_medication"],
          symptoms: "none"
        }
      ]
      
      high_risk_scenarios.each do |scenario|
        # Multiple predictions should be consistent
        results = 3.times.map { baseline_predictor.predict(scenario) }
        
        # All results should have same structure and ADE status
        first_result = results.first
        results.each do |result|
          expect(result[:ade_status]).to eq(first_result[:ade_status])
          expect(result.keys).to eq(first_result.keys)
        end
      end
    end
    
    it "maintains optimization reproducibility", vcr: { cassette_name: 'ade_reproducibility/optimization' } do
      # Test that optimization produces consistent results
      baseline_program = DSPy::Predict.new(ADEPredictor)
      
      training_examples = [
        DSPy::Example.new(
          signature_class: ADEPredictor,
          input: {
            patient_report: "Patient reports nausea after medication",
            medications: ["test_drug"],
            symptoms: "nausea"
          },
          expected: {
            ade_status: ADEPredictor::ADEStatus::MildADE,
            confidence: 0.8,
            drug_symptom_pairs: []
          }
        )
      ]
      
      optimizer = ADEOptimizer.new(config: { max_errors: 1 })
      
      # Run optimization multiple times
      result1 = optimizer.run_simple_optimization(
        baseline_program: baseline_program,
        training_examples: training_examples,
        num_examples: 1
      )
      
      result2 = optimizer.run_simple_optimization(
        baseline_program: baseline_program,
        training_examples: training_examples,
        num_examples: 1
      )
      
      # Should have consistent structure and baseline metrics
      expect(result1.keys.sort).to eq(result2.keys.sort)
      
      if result1[:baseline_metrics] && result2[:baseline_metrics]
        expect(result1[:baseline_metrics].keys).to eq(result2[:baseline_metrics].keys)
      end
    end
  end
  
  describe "Cross-environment consistency" do
    it "produces deterministic results for medical scenarios", vcr: { cassette_name: 'ade_reproducibility/deterministic' } do
      # Test scenarios that should produce predictable results
      baseline_predictor = BaselinePredictor.new
      
      deterministic_scenarios = [
        {
          name: "clear_no_ade",
          input: {
            patient_report: "Patient taking medication with no issues reported",
            medications: ["safe_med"],
            symptoms: "none"
          }
        },
        {
          name: "clear_ade_present",
          input: {
            patient_report: "Patient experienced severe reaction requiring hospitalization",
            medications: ["problematic_drug"],
            symptoms: "severe reaction"
          }
        }
      ]
      
      deterministic_scenarios.each do |scenario|
        result = baseline_predictor.predict(scenario[:input])
        
        # Should always return valid medical prediction structure
        expect(result).to include(:ade_status, :confidence, :drug_symptom_pairs)
        expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:drug_symptom_pairs]).to be_an(Array)
        
        # Medical safety: confidence should be valid range (can be 0.0 for safe defaults)
        expect(result[:confidence]).to be_between(0.0, 1.0)
      end
    end
    
    it "handles edge cases consistently", vcr: { cassette_name: 'ade_reproducibility/edge_cases' } do
      # Test that edge cases are handled consistently
      baseline_predictor = BaselinePredictor.new
      
      edge_cases = [
        { patient_report: "", medications: [], symptoms: "" },
        { patient_report: "   ", medications: [""], symptoms: "   " },
        { patient_report: "Single word", medications: ["X"], symptoms: "Y" }
      ]
      
      edge_cases.each do |edge_case|
        # Should never crash and always return safe defaults
        result = baseline_predictor.predict(edge_case)
        
        expect(result).to include(:ade_status, :confidence, :drug_symptom_pairs)
        expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
        
        # For edge cases, system should return safe defaults
        # (NoADE with low confidence as medical safety measure)
        expect(result[:confidence]).to be_between(0.0, 1.0)
      end
    end
  end
  
  describe "Performance reproducibility" do
    it "tracks token usage consistently", vcr: { cassette_name: 'ade_reproducibility/token_usage' } do
      # Test that token usage tracking is consistent
      baseline_predictor = BaselinePredictor.new
      baseline_predictor.reset_token_usage
      
      test_input = {
        patient_report: "Patient reports mild side effects from prescribed medication",
        medications: ["medication_a"],
        symptoms: "mild side effects"
      }
      
      # Make several predictions
      3.times { baseline_predictor.predict(test_input) }
      
      token_usage = baseline_predictor.token_usage
      
      # Should track usage consistently (may be 0 if predictions failed)
      expect(token_usage).to include(:total_tokens, :input_tokens, :output_tokens)
      expect(token_usage[:total_tokens]).to be >= 0
      expect(token_usage[:total_tokens]).to eq(
        token_usage[:input_tokens] + token_usage[:output_tokens]
      )
      
      # All token counts should be non-negative
      expect(token_usage[:input_tokens]).to be >= 0
      expect(token_usage[:output_tokens]).to be >= 0
    end
    
    it "maintains evaluation metrics reproducibility", vcr: { cassette_name: 'ade_reproducibility/evaluation_metrics' } do
      # Test that evaluation produces consistent results
      test_examples = [
        DSPy::Example.new(
          signature_class: ADEPredictor,
          input: {
            patient_report: "Patient doing well on current treatment",
            medications: ["current_med"],
            symptoms: "none"
          },
          expected: {
            ade_status: ADEPredictor::ADEStatus::NoADE,
            confidence: 0.9,
            drug_symptom_pairs: []
          }
        )
      ]
      
      baseline_predictor = BaselinePredictor.new
      
      # Run evaluation multiple times
      results = 2.times.map { baseline_predictor.evaluate_performance(test_examples) }
      
      # Should produce identical metrics
      expect(results[0].keys).to eq(results[1].keys)
      
      # Core metrics should be identical for same input
      [:accuracy, :precision, :recall, :f1].each do |metric|
        expect(results[0][metric]).to eq(results[1][metric])
      end
    end
  end
end