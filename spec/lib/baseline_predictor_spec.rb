# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/baseline_predictor'
require_relative '../../lib/ade_predictor'

RSpec.describe BaselinePredictor do
  let(:predictor) { BaselinePredictor.new }
  
  describe '#initialize' do
    it 'creates a DSPy::Predict instance with ADEPredictor' do
      expect(predictor.program).to be_a(DSPy::Predict)
    end
    
    it 'uses ADEPredictor signature' do
      expect(predictor.signature_class).to eq(ADEPredictor)
    end
  end
  
  describe '#predict' do
    let(:sample_input) do
      {
        patient_report: "Patient experienced severe nausea after taking aspirin for headache",
        medications: ["aspirin"],
        symptoms: "nausea, vomiting"
      }
    end
    
    it 'returns valid ADEStatus', vcr: { cassette_name: 'baseline/ade_prediction' } do
      result = predictor.predict(sample_input)
      
      expect(result).to be_a(Hash)
      expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
      expect([
        ADEPredictor::ADEStatus::NoADE,
        ADEPredictor::ADEStatus::MildADE,
        ADEPredictor::ADEStatus::SevereADE
      ]).to include(result[:ade_status])
    end
    
    it 'provides confidence score', vcr: { cassette_name: 'baseline/confidence_score' } do
      result = predictor.predict(sample_input)
      
      expect(result[:confidence]).to be_a(Numeric)
      expect(result[:confidence]).to be_between(0, 1)
    end
    
    it 'identifies drug-symptom pairs', vcr: { cassette_name: 'baseline/drug_symptom_pairs' } do
      result = predictor.predict(sample_input)
      
      expect(result[:drug_symptom_pairs]).to be_an(Array)
      result[:drug_symptom_pairs].each do |pair|
        expect(pair).to be_a(ADEPredictor::DrugSymptomPair)
        expect(pair.drug).to be_a(String)
        expect(pair.symptom).to be_a(String)
      end
    end
    
    it 'handles no ADE cases correctly', vcr: { cassette_name: 'baseline/no_ade_case' } do
      no_ade_input = {
        patient_report: "Patient reports feeling much better after taking prescribed medication",
        medications: ["ibuprofen"],
        symptoms: "none reported"
      }
      
      result = predictor.predict(no_ade_input)
      
      expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
      expect(result[:confidence]).to be_between(0, 1)
    end
    
    it 'handles complex medication cases', vcr: { cassette_name: 'baseline/complex_medications' } do
      complex_input = {
        patient_report: "Patient on multiple medications developed rash and breathing difficulties",
        medications: ["warfarin", "aspirin", "metformin"],
        symptoms: "rash, difficulty breathing, dizziness"
      }
      
      result = predictor.predict(complex_input)
      
      expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
      expect(result[:drug_symptom_pairs]).to be_an(Array)
      # Note: LLM may not always generate pairs, so we just verify structure
    end
  end
  
  describe '#predict_batch' do
    let(:sample_inputs) do
      [
        {
          patient_report: "No adverse reactions noted",
          medications: ["ibuprofen"],
          symptoms: "none"
        },
        {
          patient_report: "Severe allergic reaction to penicillin",
          medications: ["penicillin"],
          symptoms: "anaphylaxis, hives"
        }
      ]
    end
    
    it 'processes multiple examples efficiently', vcr: { cassette_name: 'baseline/batch_predictions' } do
      results = predictor.predict_batch(sample_inputs)
      
      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
      
      results.each do |result|
        expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
        expect(result[:confidence]).to be_between(0, 1)
        expect(result[:drug_symptom_pairs]).to be_an(Array)
      end
    end
    
    it 'maintains consistent output format across batch', vcr: { cassette_name: 'baseline/batch_consistency' } do
      results = predictor.predict_batch(sample_inputs)
      
      # All results should have same keys
      expected_keys = [:ade_status, :confidence, :drug_symptom_pairs]
      results.each do |result|
        expect(result.keys).to contain_exactly(*expected_keys)
      end
    end
    
    it 'handles empty batch gracefully' do
      results = predictor.predict_batch([])
      expect(results).to eq([])
    end
  end
  
  describe '#evaluate_performance' do
    let(:test_examples) do
      [
        DSPy::Example.new(
          signature_class: ADEPredictor,
          input: {
            patient_report: "No adverse reactions",
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
            patient_report: "Severe headache after aspirin",
            medications: ["aspirin"],
            symptoms: "severe headache"
          },
          expected: {
            ade_status: ADEPredictor::ADEStatus::MildADE,
            confidence: 0.9,
            drug_symptom_pairs: [
              ADEPredictor::DrugSymptomPair.new(drug: "aspirin", symptom: "severe headache")
            ]
          }
        )
      ]
    end
    
    it 'evaluates against test examples', vcr: { cassette_name: 'baseline/evaluation' } do
      metrics = predictor.evaluate_performance(test_examples)
      
      expect(metrics).to be_a(Hash)
      expect(metrics[:precision]).to be_between(0, 1)
      expect(metrics[:recall]).to be_between(0, 1)
      expect(metrics[:f1]).to be_between(0, 1)
      expect(metrics[:accuracy]).to be_between(0, 1)
    end
    
    it 'returns detailed confusion matrix', vcr: { cassette_name: 'baseline/confusion_matrix' } do
      metrics = predictor.evaluate_performance(test_examples)
      
      expect(metrics[:confusion_matrix]).to be_a(Hash)
      expect(metrics[:confusion_matrix][:matrix]).to be_a(Hash)
      expect(metrics[:confusion_matrix][:per_class]).to be_a(Hash)
    end
    
    it 'tracks total examples and correct predictions' do
      allow(predictor).to receive(:predict_batch).and_return([
        { ade_status: ADEPredictor::ADEStatus::NoADE, confidence: 0.8, drug_symptom_pairs: [] },
        { ade_status: ADEPredictor::ADEStatus::MildADE, confidence: 0.7, drug_symptom_pairs: [] }
      ])
      
      metrics = predictor.evaluate_performance(test_examples)
      
      expect(metrics[:total_examples]).to eq(2)
      expect(metrics[:correct_predictions]).to be_between(0, 2)
    end
  end
  
  describe '#token_usage' do
    it 'tracks token usage for cost analysis' do
      expect(predictor).to respond_to(:token_usage)
      
      usage = predictor.token_usage
      expect(usage).to be_a(Hash)
      expect(usage).to have_key(:total_tokens)
      expect(usage).to have_key(:input_tokens) 
      expect(usage).to have_key(:output_tokens)
    end
    
    it 'resets token count when requested' do
      predictor.reset_token_usage
      usage = predictor.token_usage
      
      expect(usage[:total_tokens]).to eq(0)
      expect(usage[:input_tokens]).to eq(0)
      expect(usage[:output_tokens]).to eq(0)
    end
  end
  
  describe 'error handling' do
    it 'handles invalid input gracefully' do
      invalid_input = {
        patient_report: nil,
        medications: nil,
        symptoms: nil
      }
      
      expect { predictor.predict(invalid_input) }.not_to raise_error
    end
    
    it 'handles empty input gracefully' do
      empty_input = {
        patient_report: "",
        medications: [],
        symptoms: ""
      }
      
      result = predictor.predict(empty_input)
      expect(result[:ade_status]).to be_a(ADEPredictor::ADEStatus)
    end
    
    it 'handles LLM response parsing errors' do
      sample_input = {
        patient_report: "Test input for error handling",
        medications: ["aspirin"],
        symptoms: "headache"
      }
      
      # Mock an invalid response from the LLM
      allow(predictor.program).to receive(:call).and_raise(StandardError.new("Parsing error"))
      
      expect { predictor.predict(sample_input) }.not_to raise_error
    end
  end
end