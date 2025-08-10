# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/evaluation_metrics'
require_relative '../../lib/ade_predictor'

RSpec.describe EvaluationMetrics do
  describe '.calculate_precision' do
    it 'calculates precision correctly for binary classification' do
      # TP=5, FP=2 -> precision = 5/(5+2) = 0.714
      true_positives = 5
      false_positives = 2
      
      precision = EvaluationMetrics.calculate_precision(true_positives, false_positives)
      expect(precision).to be_within(0.001).of(0.714)
    end
    
    it 'handles edge case of no positive predictions' do
      # No predictions made (TP=0, FP=0)
      precision = EvaluationMetrics.calculate_precision(0, 0)
      expect(precision).to eq(0.0)
    end
    
    it 'returns 0 when no true positives exist' do
      # Only false positives (TP=0, FP=5)
      precision = EvaluationMetrics.calculate_precision(0, 5)
      expect(precision).to eq(0.0)
    end
    
    it 'returns 1.0 for perfect precision' do
      # All predictions correct (TP=10, FP=0)
      precision = EvaluationMetrics.calculate_precision(10, 0)
      expect(precision).to eq(1.0)
    end
  end
  
  describe '.calculate_recall' do
    it 'calculates recall correctly for binary classification' do
      # TP=5, FN=3 -> recall = 5/(5+3) = 0.625
      true_positives = 5
      false_negatives = 3
      
      recall = EvaluationMetrics.calculate_recall(true_positives, false_negatives)
      expect(recall).to be_within(0.001).of(0.625)
    end
    
    it 'handles edge case of no actual positives' do
      # No actual positives in dataset (TP=0, FN=0)
      recall = EvaluationMetrics.calculate_recall(0, 0)
      expect(recall).to eq(0.0)
    end
    
    it 'returns 0 when no true positives exist' do
      # Missed all positives (TP=0, FN=5)
      recall = EvaluationMetrics.calculate_recall(0, 5)
      expect(recall).to eq(0.0)
    end
    
    it 'returns 1.0 for perfect recall' do
      # Found all positives (TP=10, FN=0)
      recall = EvaluationMetrics.calculate_recall(10, 0)
      expect(recall).to eq(1.0)
    end
  end
  
  describe '.calculate_f1_score' do
    it 'calculates F1 as harmonic mean of precision and recall' do
      precision = 0.8
      recall = 0.6
      # F1 = 2 * (0.8 * 0.6) / (0.8 + 0.6) = 0.686
      
      f1 = EvaluationMetrics.calculate_f1_score(precision, recall)
      expect(f1).to be_within(0.001).of(0.686)
    end
    
    it 'returns 0 when both precision and recall are 0' do
      f1 = EvaluationMetrics.calculate_f1_score(0.0, 0.0)
      expect(f1).to eq(0.0)
    end
    
    it 'handles perfect predictions (F1 = 1.0)' do
      f1 = EvaluationMetrics.calculate_f1_score(1.0, 1.0)
      expect(f1).to eq(1.0)
    end
    
    it 'returns 0 when either precision or recall is 0' do
      expect(EvaluationMetrics.calculate_f1_score(0.0, 0.5)).to eq(0.0)
      expect(EvaluationMetrics.calculate_f1_score(0.5, 0.0)).to eq(0.0)
    end
  end
  
  describe '.confusion_matrix' do
    let(:predictions) do
      [
        ADEPredictor::ADEStatus::NoADE,
        ADEPredictor::ADEStatus::MildADE,
        ADEPredictor::ADEStatus::SevereADE,
        ADEPredictor::ADEStatus::NoADE,
        ADEPredictor::ADEStatus::MildADE
      ]
    end
    
    let(:actuals) do
      [
        ADEPredictor::ADEStatus::NoADE,    # Correct
        ADEPredictor::ADEStatus::MildADE,   # Correct
        ADEPredictor::ADEStatus::MildADE,   # Wrong (predicted Severe)
        ADEPredictor::ADEStatus::NoADE,     # Correct
        ADEPredictor::ADEStatus::SevereADE  # Wrong (predicted Mild)
      ]
    end
    
    it 'generates correct confusion matrix for multi-class' do
      matrix = EvaluationMetrics.confusion_matrix(predictions, actuals)
      
      expect(matrix).to be_a(Hash)
      expect(matrix[:matrix]).to be_a(Hash)
      
      # Check NoADE predictions
      expect(matrix[:matrix][ADEPredictor::ADEStatus::NoADE][ADEPredictor::ADEStatus::NoADE]).to eq(2)
      
      # Check MildADE predictions
      expect(matrix[:matrix][ADEPredictor::ADEStatus::MildADE][ADEPredictor::ADEStatus::MildADE]).to eq(1)
      expect(matrix[:matrix][ADEPredictor::ADEStatus::MildADE][ADEPredictor::ADEStatus::SevereADE]).to eq(1)
      
      # Check SevereADE predictions
      expect(matrix[:matrix][ADEPredictor::ADEStatus::SevereADE][ADEPredictor::ADEStatus::MildADE]).to eq(1)
    end
    
    it 'tracks true positives, false positives, true negatives, false negatives' do
      matrix = EvaluationMetrics.confusion_matrix(predictions, actuals)
      
      expect(matrix).to have_key(:tp)
      expect(matrix).to have_key(:fp)
      expect(matrix).to have_key(:tn)
      expect(matrix).to have_key(:fn)
    end
    
    it 'supports ADEStatus enum values' do
      # Should not raise error with enum values
      expect { 
        EvaluationMetrics.confusion_matrix(predictions, actuals)
      }.not_to raise_error
    end
    
    it 'calculates per-class metrics' do
      matrix = EvaluationMetrics.confusion_matrix(predictions, actuals)
      
      expect(matrix[:per_class]).to be_a(Hash)
      expect(matrix[:per_class]).to have_key(ADEPredictor::ADEStatus::NoADE)
      expect(matrix[:per_class]).to have_key(ADEPredictor::ADEStatus::MildADE)
      expect(matrix[:per_class]).to have_key(ADEPredictor::ADEStatus::SevereADE)
      
      # Each class should have precision, recall, f1
      matrix[:per_class].each do |_status, metrics|
        expect(metrics).to have_key(:precision)
        expect(metrics).to have_key(:recall)
        expect(metrics).to have_key(:f1)
      end
    end
  end
  
  describe '.create_dspy_metric' do
    let(:example) do
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: "Patient experienced nausea after taking aspirin",
          medications: ["aspirin"],
          symptoms: "nausea"
        },
        expected: {
          ade_status: ADEPredictor::ADEStatus::MildADE,
          confidence: 0.9,
          drug_symptom_pairs: []
        }
      )
    end
    
    it 'returns a callable metric for DSPy::Evaluate' do
      metric = EvaluationMetrics.create_dspy_metric
      
      expect(metric).to respond_to(:call)
      expect(metric.arity).to eq(2)  # Takes example and prediction
    end
    
    it 'correctly scores ADEStatus predictions' do
      metric = EvaluationMetrics.create_dspy_metric
      
      # Correct prediction
      correct_prediction = { 
        ade_status: ADEPredictor::ADEStatus::MildADE,
        confidence: 0.8,
        drug_symptom_pairs: []
      }
      expect(metric.call(example, correct_prediction)).to be true
      
      # Incorrect prediction
      incorrect_prediction = { 
        ade_status: ADEPredictor::ADEStatus::NoADE,
        confidence: 0.8,
        drug_symptom_pairs: []
      }
      expect(metric.call(example, incorrect_prediction)).to be false
    end
    
    it 'considers confidence thresholds' do
      metric = EvaluationMetrics.create_dspy_metric(confidence_threshold: 0.7)
      
      # Low confidence prediction (even if correct)
      low_confidence_prediction = { 
        ade_status: ADEPredictor::ADEStatus::MildADE,
        confidence: 0.5,
        drug_symptom_pairs: []
      }
      expect(metric.call(example, low_confidence_prediction)).to be false
      
      # High confidence prediction
      high_confidence_prediction = { 
        ade_status: ADEPredictor::ADEStatus::MildADE,
        confidence: 0.8,
        drug_symptom_pairs: []
      }
      expect(metric.call(example, high_confidence_prediction)).to be true
    end
    
    it 'handles missing predictions gracefully' do
      metric = EvaluationMetrics.create_dspy_metric
      
      expect(metric.call(example, nil)).to be false
      expect(metric.call(example, {})).to be false
    end
  end
  
  describe '.evaluate_batch' do
    let(:examples) do
      [
        DSPy::Example.new(
          signature_class: ADEPredictor,
          input: { patient_report: "text1", medications: [], symptoms: "" },
          expected: { ade_status: ADEPredictor::ADEStatus::NoADE, confidence: 1.0, drug_symptom_pairs: [] }
        ),
        DSPy::Example.new(
          signature_class: ADEPredictor,
          input: { patient_report: "text2", medications: [], symptoms: "" },
          expected: { ade_status: ADEPredictor::ADEStatus::MildADE, confidence: 1.0, drug_symptom_pairs: [] }
        )
      ]
    end
    
    let(:predictions) do
      [
        { ade_status: ADEPredictor::ADEStatus::NoADE, confidence: 0.9, drug_symptom_pairs: [] },
        { ade_status: ADEPredictor::ADEStatus::MildADE, confidence: 0.8, drug_symptom_pairs: [] }
      ]
    end
    
    it 'evaluates a batch of predictions' do
      results = EvaluationMetrics.evaluate_batch(examples, predictions)
      
      expect(results).to be_a(Hash)
      expect(results[:precision]).to be_between(0, 1)
      expect(results[:recall]).to be_between(0, 1)
      expect(results[:f1]).to be_between(0, 1)
      expect(results[:accuracy]).to eq(1.0)  # Both predictions correct
    end
    
    it 'returns detailed confusion matrix' do
      results = EvaluationMetrics.evaluate_batch(examples, predictions)
      
      expect(results[:confusion_matrix]).to be_a(Hash)
      expect(results[:confusion_matrix][:matrix]).to be_a(Hash)
    end
  end
end