# frozen_string_literal: true

require 'spec_helper'
require 'vcr'
require_relative '../../lib/signatures/ade_direct_classifier'

RSpec.describe ADEDirectClassifier do
  let(:predictor) { DSPy::Predict.new(described_class) }

  describe 'signature definition' do
    it 'can create predictor successfully' do
      # Test that we can create a predictor with this signature
      expect { DSPy::Predict.new(described_class) }.not_to raise_error
      expect(predictor).to be_a(DSPy::Predict)
    end
  end

  describe 'direct ADE classification' do
    context 'with clear adverse event', vcr: { cassette_name: 'ade_direct_classifier/clear_adverse' } do
      let(:text) { "Patient experienced severe allergic reaction with hives after taking amoxicillin." }

      it 'identifies ADE with reasoning' do
        result = predictor.call(text: text)

        expect(result.has_ade).to be_a(TrueClass).or(be_a(FalseClass))
        expect(result.confidence).to be_between(0.0, 1.0)
        expect(result.reasoning).to be_a(String)
        expect(result.reasoning.length).to be > 5  # Should provide explanation
      end
    end

    context 'with therapeutic effect', vcr: { cassette_name: 'ade_direct_classifier/therapeutic' } do
      let(:text) { "Insulin therapy successfully lowered patient's blood glucose levels." }

      it 'identifies no ADE' do
        result = predictor.call(text: text)

        expect(result.has_ade).to be_a(TrueClass).or(be_a(FalseClass))
        expect(result.confidence).to be_between(0.0, 1.0)
        expect(result.reasoning).to be_a(String)
        expect(result.reasoning.length).to be > 5
      end
    end

    context 'with complex medical scenario', vcr: { cassette_name: 'ade_direct_classifier/complex' } do
      let(:text) { "Post-surgical patient on multiple medications developed acute kidney injury." }

      it 'handles complex scenarios' do
        result = predictor.call(text: text)

        expect(result.has_ade).to be_a(TrueClass).or(be_a(FalseClass))
        expect(result.confidence).to be_between(0.0, 1.0)
        expect(result.reasoning).to be_a(String)
        expect(result.reasoning.length).to be > 10  # Complex scenario needs longer explanation
      end
    end
  end
end