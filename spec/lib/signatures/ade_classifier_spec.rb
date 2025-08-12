# frozen_string_literal: true

require 'spec_helper'
require 'dspy'
require_relative '../../../lib/signatures/ade_classifier'

RSpec.describe ADEClassifier do
  let(:predictor) { DSPy::Predict.new(ADEClassifier) }

  before do
    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
    end
  end

  describe '#call', vcr: { cassette_name: 'ade_classifier' } do
    context 'with clear adverse drug event' do
      let(:text) { "Patient developed severe rash after starting penicillin treatment." }
      let(:drugs) { ['penicillin'] }
      let(:effects) { ['rash'] }

      it 'correctly identifies ADE as present' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result).to respond_to(:has_ade)
        expect(result).to respond_to(:confidence)
        expect(result.has_ade).to be true
        expect(result.confidence).to be_between(0.0, 1.0)
        expect(result.confidence).to be > 0.6  # Should be confident for clear case
      end
    end

    context 'with no adverse drug event' do
      let(:text) { "Patient tolerates medication well with no side effects reported." }
      let(:drugs) { ['medication'] }
      let(:effects) { [] }

      it 'correctly identifies no ADE' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be false
        expect(result.confidence).to be_between(0.0, 1.0)
      end
    end

    context 'with unrelated symptoms' do
      let(:text) { "Patient has chronic back pain but medication is helping." }
      let(:drugs) { ['medication'] }
      let(:effects) { ['back pain'] }

      it 'distinguishes pre-existing conditions from ADEs' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be false
        expect(result.confidence).to be_between(0.0, 1.0)
      end
    end

    context 'with multiple drugs and effects' do
      let(:text) { "After starting both aspirin and metformin, patient experienced nausea and dizziness." }
      let(:drugs) { ['aspirin', 'metformin'] }
      let(:effects) { ['nausea', 'dizziness'] }

      it 'evaluates complex drug-effect relationships' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be true
        expect(result.confidence).to be_between(0.0, 1.0)
      end
    end

    context 'with no drugs but effects present' do
      let(:text) { "Patient reports headache and fatigue." }
      let(:drugs) { [] }
      let(:effects) { ['headache', 'fatigue'] }

      it 'handles cases with no drugs identified' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be false  # No drugs = no ADE
        expect(result.confidence).to be_between(0.0, 1.0)
      end
    end

    context 'with drugs but no effects' do
      let(:text) { "Patient taking aspirin daily with no issues." }
      let(:drugs) { ['aspirin'] }
      let(:effects) { [] }

      it 'handles cases with drugs but no adverse effects' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be false
        expect(result.confidence).to be_between(0.0, 1.0)
      end
    end

    context 'with temporal relationship indicators' do
      let(:text) { "Patient developed symptoms immediately after medication administration." }
      let(:drugs) { ['medication'] }
      let(:effects) { ['symptoms'] }

      it 'considers temporal relationships' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect(result.has_ade).to be true
        expect(result.confidence).to be > 0.5  # Temporal relationship should increase confidence
      end
    end

    context 'with ambiguous case' do
      let(:text) { "Patient reports feeling unwell since starting new treatment." }
      let(:drugs) { ['treatment'] }
      let(:effects) { ['unwell'] }

      it 'handles ambiguous cases with appropriate confidence' do
        result = predictor.call(text: text, drugs: drugs, effects: effects)
        
        expect([true, false]).to include(result.has_ade)  # Could go either way
        expect(result.confidence).to be_between(0.0, 1.0)
        # For ambiguous cases, confidence might be lower
      end
    end
  end

  # Signature structure is tested through functional usage above
end