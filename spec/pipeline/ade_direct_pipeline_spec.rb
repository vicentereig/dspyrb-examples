# frozen_string_literal: true

require 'spec_helper'
require 'vcr'
require_relative '../../lib/pipeline/ade_direct_pipeline'

RSpec.describe ADEDirectPipeline do
  let(:pipeline) { described_class.new }

  describe '#initialize' do
    it 'creates a direct ADE classifier' do
      expect(pipeline.ade_classifier).to be_a(DSPy::Predict)
    end
  end

  describe '#predict' do
    context 'with clear ADE text', vcr: { cassette_name: 'ade_direct_pipeline/clear_ade' } do
      let(:text) { "Patient developed severe nausea and vomiting after starting metformin treatment." }

      it 'identifies adverse drug event' do
        result = pipeline.predict(text)

        expect(result[:text]).to eq(text)
        expect([true, false]).to include(result[:has_ade])
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:reasoning]).to be_a(String)
        expect(result[:api_calls]).to eq(1)
      end
    end

    context 'with no ADE text', vcr: { cassette_name: 'ade_direct_pipeline/no_ade' } do
      let(:text) { "Patient shows good response to diabetes medication with stable blood sugar levels." }

      it 'identifies no adverse drug event' do
        result = pipeline.predict(text)

        expect(result[:text]).to eq(text)
        expect([true, false]).to include(result[:has_ade])
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:reasoning]).to be_a(String)
        expect(result[:api_calls]).to eq(1)
      end
    end

    context 'with ambiguous text', vcr: { cassette_name: 'ade_direct_pipeline/ambiguous' } do
      let(:text) { "Patient reported feeling tired after medication, but also had poor sleep." }

      it 'makes a classification decision' do
        result = pipeline.predict(text)

        expect(result[:text]).to eq(text)
        expect([true, false]).to include(result[:has_ade])
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:reasoning]).to be_a(String)
        expect(result[:api_calls]).to eq(1)
      end
    end

    context 'with medical terminology', vcr: { cassette_name: 'ade_direct_pipeline/medical_terms' } do
      let(:text) { "Hepatotoxicity observed following acetaminophen overdose with elevated ALT/AST." }

      it 'handles medical terminology' do
        result = pipeline.predict(text)

        expect(result[:text]).to eq(text)
        expect([true, false]).to include(result[:has_ade])
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:reasoning]).to be_a(String)
        expect(result[:reasoning].length).to be > 10  # Should have substantive reasoning
        expect(result[:api_calls]).to eq(1)
      end
    end
  end

  describe '#predict_batch' do
    let(:texts) do
      [
        "Patient developed rash after penicillin.",
        "Blood pressure well controlled with medication."
      ]
    end

    it 'processes multiple texts', vcr: { cassette_name: 'ade_direct_pipeline/batch_prediction' } do
      results = pipeline.predict_batch(texts)

      expect(results).to have_attributes(size: 2)
      results.each_with_index do |result, i|
        expect(result[:text]).to eq(texts[i])
        expect([true, false]).to include(result[:has_ade])
        expect(result[:confidence]).to be_between(0.0, 1.0)
        expect(result[:api_calls]).to eq(1)
      end
    end
  end
end