# frozen_string_literal: true

require 'spec_helper'
require 'dspy'
require_relative '../../../lib/signatures/effect_extractor'

RSpec.describe EffectExtractor do
  let(:predictor) { DSPy::Predict.new(EffectExtractor) }

  before do
    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
    end
  end

  describe '#call', vcr: { cassette_name: 'effect_extractor' } do
    context 'with single adverse effect' do
      let(:text) { "Patient developed severe nausea after medication." }

      it 'extracts the adverse effect correctly' do
        result = predictor.call(text: text)
        
        expect(result).to respond_to(:effects)
        expect(result.effects).to be_an(Array)
        expect(result.effects.any? { |effect| effect.downcase.include?('nausea') }).to be true
      end
    end

    context 'with multiple adverse effects' do
      let(:text) { "Patient experienced both dizziness and fatigue following treatment." }

      it 'extracts all adverse effects' do
        result = predictor.call(text: text)
        
        expect(result.effects).to be_an(Array)
        expect(result.effects.size).to be >= 2
        expect(result.effects.map(&:downcase)).to include('dizziness')
        expect(result.effects.map(&:downcase)).to include('fatigue')
      end
    end

    context 'with medical terminology' do
      let(:text) { "Intravenous azithromycin-induced ototoxicity was observed." }

      it 'extracts medical adverse effects' do
        result = predictor.call(text: text)
        
        expect(result.effects).to be_an(Array)
        expect(result.effects.map(&:downcase)).to include('ototoxicity')
      end
    end

    context 'with no adverse effects mentioned' do
      let(:text) { "Patient tolerated medication well with no side effects." }

      it 'returns empty array when no effects present' do
        result = predictor.call(text: text)
        
        expect(result.effects).to be_an(Array)
        expect(result.effects).to be_empty
      end
    end

    context 'with complex medical text' do
      let(:text) { "A 5-month-old infant became lethargic and poorly responsive after receiving brimonidine." }

      it 'extracts effects from complex descriptions' do
        result = predictor.call(text: text)
        
        expect(result.effects).to be_an(Array)
        expect(result.effects.any? { |effect| effect.downcase.include?('letharg') }).to be true
      end
    end

    context 'distinguishing effects from symptoms' do
      let(:text) { "Patient had pre-existing headache but developed new onset rash after medication." }

      it 'focuses on medication-related effects' do
        result = predictor.call(text: text)
        
        expect(result.effects).to be_an(Array)
        expect(result.effects.map(&:downcase)).to include('rash')
        # Should ideally not include pre-existing conditions
      end
    end
  end

  # Signature structure is tested through functional usage above
end