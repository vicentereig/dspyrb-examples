# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_predictor'

RSpec.describe ADEPredictor do
  describe 'signature structure' do
    it 'inherits from DSPy::Signature' do
      expect(ADEPredictor).to be < DSPy::Signature
    end
    
    it 'has a description' do
      expect(ADEPredictor.description).to eq("Predict if a patient report contains an adverse drug event")
    end
  end
  
  describe 'input fields' do
    let(:input_schema) { ADEPredictor.input_json_schema }
    
    it 'requires patient_report as String input' do
      expect(input_schema[:properties]).to have_key(:patient_report)
      expect(input_schema[:properties][:patient_report][:type]).to eq("string")
      expect(input_schema[:required]).to include("patient_report")
    end
    
    it 'requires medications as Array[String] input' do
      expect(input_schema[:properties]).to have_key(:medications)
      expect(input_schema[:properties][:medications][:type]).to eq("array")
      expect(input_schema[:properties][:medications][:items][:type]).to eq("string")
      expect(input_schema[:required]).to include("medications")
    end
    
    it 'requires symptoms as String input' do
      expect(input_schema[:properties]).to have_key(:symptoms)
      expect(input_schema[:properties][:symptoms][:type]).to eq("string")
      expect(input_schema[:required]).to include("symptoms")
    end
  end
  
  describe 'output fields' do
    let(:output_schema) { ADEPredictor.output_json_schema }
    
    it 'outputs ade_status as ADEStatus enum' do
      expect(output_schema[:properties]).to have_key(:ade_status)
      expect(output_schema[:properties][:ade_status][:enum]).to contain_exactly(
        "no_adverse_event", "mild_adverse_event", "severe_adverse_event"
      )
      expect(output_schema[:required]).to include("ade_status")
    end
    
    it 'outputs confidence as Float between 0 and 1' do
      expect(output_schema[:properties]).to have_key(:confidence)
      expect(output_schema[:properties][:confidence][:type]).to eq("number")
      expect(output_schema[:required]).to include("confidence")
    end
    
    it 'outputs drug_symptom_pairs as Array of Hashes' do
      expect(output_schema[:properties]).to have_key(:drug_symptom_pairs)
      expect(output_schema[:properties][:drug_symptom_pairs][:type]).to eq("array")
      expect(output_schema[:required]).to include("drug_symptom_pairs")
    end
  end
  
  describe 'DrugSymptomPair struct' do
    it 'defines DrugSymptomPair as a T::Struct' do
      expect(ADEPredictor::DrugSymptomPair).to be < T::Struct
    end
    
    it 'has drug and symptom fields' do
      pair = ADEPredictor::DrugSymptomPair.new(drug: 'aspirin', symptom: 'nausea')
      expect(pair.drug).to eq('aspirin')
      expect(pair.symptom).to eq('nausea')
    end
  end
  
  describe 'ADEStatus enum' do
    it 'defines ADEStatus enum with correct values' do
      expect(ADEPredictor::ADEStatus).to be < T::Enum
      
      expect(ADEPredictor::ADEStatus::NoADE.serialize).to eq('no_adverse_event')
      expect(ADEPredictor::ADEStatus::MildADE.serialize).to eq('mild_adverse_event')
      expect(ADEPredictor::ADEStatus::SevereADE.serialize).to eq('severe_adverse_event')
    end
    
    it 'has exactly three enum values' do
      expect(ADEPredictor::ADEStatus.values.size).to eq(3)
    end
    
    it 'can deserialize from string values' do
      expect(ADEPredictor::ADEStatus.deserialize('no_adverse_event')).to eq(ADEPredictor::ADEStatus::NoADE)
      expect(ADEPredictor::ADEStatus.deserialize('mild_adverse_event')).to eq(ADEPredictor::ADEStatus::MildADE)
      expect(ADEPredictor::ADEStatus.deserialize('severe_adverse_event')).to eq(ADEPredictor::ADEStatus::SevereADE)
    end
  end
end