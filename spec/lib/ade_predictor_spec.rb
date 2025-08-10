# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_predictor'

RSpec.describe ADEPredictor do
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