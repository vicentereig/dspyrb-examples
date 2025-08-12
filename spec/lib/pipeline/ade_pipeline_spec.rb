# frozen_string_literal: true

require 'spec_helper'
require 'dspy'
require_relative '../../../lib/pipeline/ade_pipeline'

RSpec.describe ADEPipeline do
  let(:pipeline) { ADEPipeline.new }

  before do
    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
    end
  end

  describe '#initialize' do
    it 'creates predictor instances for all three stages' do
      expect(pipeline.drug_extractor).to be_a(DSPy::Predict)
      expect(pipeline.effect_extractor).to be_a(DSPy::Predict)
      expect(pipeline.ade_classifier).to be_a(DSPy::Predict)
    end
  end

  describe '#predict', vcr: { cassette_name: 'ade_pipeline/basic_prediction' } do
    let(:text) { "Patient developed headache after taking aspirin." }

    it 'processes text through all three stages' do
      result = pipeline.predict(text)
      
      expect(result).to be_a(Hash)
      expect(result).to include(:text, :drugs, :effects, :has_ade, :confidence, :stages)
      
      expect(result[:text]).to eq(text)
      expect(result[:drugs]).to be_an(Array)
      expect(result[:effects]).to be_an(Array)
      expect([true, false]).to include(result[:has_ade])
      expect(result[:confidence]).to be_between(0.0, 1.0)
      
      # Verify stages results are included
      expect(result[:stages]).to include(:drug_extraction, :effect_extraction, :classification)
    end
  end

  describe '#predict_batch', vcr: { cassette_name: 'ade_pipeline/batch_prediction' } do
    let(:texts) do
      [
        "Patient experienced nausea after taking metformin.",
        "No adverse effects reported with current medication."
      ]
    end

    it 'processes multiple texts' do
      results = pipeline.predict_batch(texts)
      
      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
      
      results.each do |result|
        expect(result).to include(:text, :drugs, :effects, :has_ade, :confidence)
      end
    end
  end
end