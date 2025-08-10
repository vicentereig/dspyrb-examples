# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_optimizer'
require_relative '../../lib/baseline_predictor'
require_relative '../../lib/dataset_loader'

RSpec.describe ADEOptimizer do
  let(:optimizer) { ADEOptimizer.new }
  let(:baseline_predictor) { BaselinePredictor.new }
  
  let(:train_examples) do
    [
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: "No adverse reactions noted",
          medications: ["ibuprofen"],
          symptoms: "none"
        },
        expected: {
          ade_status: ADEPredictor::ADEStatus::NoADE,
          confidence: 1.0,
          drug_symptom_pairs: []
        }
      ),
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: "Patient experienced mild nausea after taking aspirin",
          medications: ["aspirin"],
          symptoms: "mild nausea"
        },
        expected: {
          ade_status: ADEPredictor::ADEStatus::MildADE,
          confidence: 0.8,
          drug_symptom_pairs: [
            ADEPredictor::DrugSymptomPair.new(drug: "aspirin", symptom: "mild nausea")
          ]
        }
      ),
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: "Severe allergic reaction to penicillin with anaphylaxis",
          medications: ["penicillin"],
          symptoms: "anaphylaxis, difficulty breathing"
        },
        expected: {
          ade_status: ADEPredictor::ADEStatus::SevereADE,
          confidence: 0.95,
          drug_symptom_pairs: [
            ADEPredictor::DrugSymptomPair.new(drug: "penicillin", symptom: "anaphylaxis")
          ]
        }
      )
    ]
  end
  
  let(:validation_examples) do
    [
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: "Patient tolerated medication well",
          medications: ["acetaminophen"],
          symptoms: "none"
        },
        expected: {
          ade_status: ADEPredictor::ADEStatus::NoADE,
          confidence: 1.0,
          drug_symptom_pairs: []
        }
      )
    ]
  end
  
  describe '#initialize' do
    it 'creates an optimizer instance' do
      expect(optimizer).to be_an(ADEOptimizer)
    end
    
    it 'initializes with default configuration' do
      expect(optimizer.config).to be_a(Hash)
      expect(optimizer.config[:max_errors]).to eq(3)
      expect(optimizer.config[:display_progress]).to be true
    end
  end
  
  describe '#run_simple_optimization' do
    it 'optimizes with SimpleOptimizer', vcr: { cassette_name: 'optimization/simple_optimizer' } do
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      expect(result).to be_a(Hash)
      expect(result[:optimized_program]).not_to be_nil
      expect(result[:baseline_metrics]).to be_a(Hash)
      expect(result[:optimized_metrics]).to be_a(Hash)
    end
    
    it 'improves F1 score over baseline', vcr: { cassette_name: 'optimization/simple_improvement' } do
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      baseline_f1 = result[:baseline_metrics][:f1]
      optimized_f1 = result[:optimized_metrics][:f1]
      
      expect(optimized_f1).to be >= baseline_f1
      expect(result[:improvement_percent]).to be >= 0
    end
    
    it 'selects effective few-shot examples' do
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        num_examples: 2
      )
      
      expect(result[:selected_examples]).to be_an(Array)
      expect(result[:selected_examples].size).to eq(2)
    end
    
    it 'tracks optimization history' do
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      expect(result[:history]).to be_a(Hash)
      expect(result[:history][:optimizer_type]).to eq('SimpleOptimizer')
      expect(result[:history][:training_examples_count]).to eq(3)
    end
  end
  
  describe '#run_mipro_optimization' do
    it 'optimizes with MIPROv2', vcr: { cassette_name: 'optimization/mipro_v2' } do
      result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples
      )
      
      expect(result).to be_a(Hash)
      expect(result[:optimized_program]).not_to be_nil
      expect(result[:baseline_metrics]).to be_a(Hash)
      expect(result[:optimized_metrics]).to be_a(Hash)
    end
    
    it 'uses bootstrap sampling effectively', vcr: { cassette_name: 'optimization/mipro_bootstrap' } do
      result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples,
        k_demos: 3,
        num_candidates: 5
      )
      
      expect(result[:history][:k_demos]).to eq(3)
      expect(result[:history][:num_candidates]).to eq(5)
      expect(result[:history][:bootstrap_samples]).to be > 0
    end
    
    it 'explores multiple prompt candidates', vcr: { cassette_name: 'optimization/mipro_candidates' } do
      result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples,
        num_candidates: 8
      )
      
      expect(result[:candidates_explored]).to eq(8)
      expect(result[:best_candidate_score]).to be_between(0, 1)
    end
    
    it 'achieves higher improvement than SimpleOptimizer', vcr: { cassette_name: 'optimization/mipro_vs_simple' } do
      simple_result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      mipro_result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples
      )
      
      expect(mipro_result[:improvement_percent]).to be >= simple_result[:improvement_percent]
    end
  end
  
  describe '#compare_optimizers' do
    it 'compares all optimization methods', vcr: { cassette_name: 'optimization/comparison' } do
      comparison = optimizer.compare_optimizers(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples
      )
      
      expect(comparison).to be_a(Hash)
      expect(comparison[:baseline]).to be_a(Hash)
      expect(comparison[:simple_optimizer]).to be_a(Hash)
      expect(comparison[:mipro_v2]).to be_a(Hash)
    end
    
    it 'ranks optimizers by performance' do
      comparison = optimizer.compare_optimizers(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples
      )
      
      expect(comparison[:ranking]).to be_an(Array)
      expect(comparison[:ranking].size).to eq(3)
      expect(comparison[:best_optimizer]).to be_a(String)
    end
    
    it 'provides detailed performance analysis' do
      comparison = optimizer.compare_optimizers(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples
      )
      
      expect(comparison[:analysis]).to be_a(Hash)
      expect(comparison[:analysis][:recall_focus]).to be_a(Hash)
      expect(comparison[:analysis][:precision_tradeoff]).to be_a(Hash)
    end
  end
  
  describe '#evaluate_on_test_set' do
    let(:test_examples) { validation_examples }
    
    it 'evaluates optimized program on held-out test set' do
      # First optimize
      optimization_result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      # Then evaluate on test set
      test_results = optimizer.evaluate_on_test_set(
        optimized_program: optimization_result[:optimized_program],
        test_examples: test_examples
      )
      
      expect(test_results[:precision]).to be_between(0, 1)
      expect(test_results[:recall]).to be_between(0, 1)
      expect(test_results[:f1]).to be_between(0, 1)
    end
    
    it 'maintains performance on unseen data' do
      optimization_result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      test_results = optimizer.evaluate_on_test_set(
        optimized_program: optimization_result[:optimized_program],
        test_examples: test_examples
      )
      
      # Performance shouldn't drop dramatically on test set
      expect(test_results[:f1]).to be >= 0.3  # Reasonable threshold
    end
  end
  
  describe 'medical safety focus' do
    it 'prioritizes recall over precision for safety' do
      result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples,
        validation_examples: validation_examples,
        optimization_mode: 'recall_focused'
      )
      
      expect(result[:optimized_metrics][:recall]).to be >= result[:baseline_metrics][:recall]
      expect(result[:safety_analysis]).to be_a(Hash)
      expect(result[:safety_analysis][:missed_ades]).to be_an(Integer)
    end
    
    it 'analyzes false negative rate (missed ADEs)' do
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: train_examples
      )
      
      expect(result[:safety_metrics]).to be_a(Hash)
      expect(result[:safety_metrics][:false_negative_rate]).to be_between(0, 1)
      expect(result[:safety_metrics][:critical_misses]).to be_an(Integer)
    end
  end
  
  describe 'error handling' do
    it 'handles optimization failures gracefully' do
      # Mock a failure in optimization
      allow_any_instance_of(DSPy::Teleprompt::SimpleOptimizer).to receive(:compile).and_raise(StandardError.new("Optimization failed"))
      
      expect {
        optimizer.run_simple_optimization(
          baseline_program: baseline_predictor.program,
          training_examples: train_examples
        )
      }.not_to raise_error
    end
    
    it 'validates training examples before optimization' do
      # Test with empty examples instead of nil values to avoid Sorbet validation
      result = optimizer.run_simple_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: []
      )
      
      expect(result[:error]).to include("Invalid training examples")
    end
    
    it 'handles insufficient training data' do
      minimal_examples = [train_examples.first]
      
      result = optimizer.run_mipro_optimization(
        baseline_program: baseline_predictor.program,
        training_examples: minimal_examples,
        validation_examples: validation_examples
      )
      
      expect(result[:warning]).to include("Insufficient training data")
    end
  end
end