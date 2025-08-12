# frozen_string_literal: true

require 'spec_helper'
require 'dspy'
require_relative '../../../lib/signatures/drug_extractor'

RSpec.describe DrugExtractor do
  let(:predictor) { DSPy::Predict.new(DrugExtractor) }

  before do
    DSPy.configure do |c|
      c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
    end
  end

  describe '#call', vcr: { cassette_name: 'drug_extractor' } do
    context 'with single drug mention' do
      let(:text) { "Patient developed headache after taking aspirin 500mg." }

      it 'extracts the drug name correctly' do
        result = predictor.call(text: text)
        
        expect(result).to respond_to(:drugs)
        expect(result.drugs).to be_an(Array)
        expect(result.drugs).to include('aspirin')
      end
    end

    context 'with multiple drug mentions' do
      let(:text) { "Patient reports nausea after taking both metformin and lisinopril daily." }

      it 'extracts all drug names' do
        result = predictor.call(text: text)
        
        expect(result.drugs).to be_an(Array)
        expect(result.drugs.size).to be >= 2
        expect(result.drugs.map(&:downcase)).to include('metformin')
        expect(result.drugs.map(&:downcase)).to include('lisinopril')
      end
    end

    context 'with no drug mentions' do
      let(:text) { "Patient feels well today with no medications taken." }

      it 'returns empty array' do
        result = predictor.call(text: text)
        
        expect(result.drugs).to be_an(Array)
        expect(result.drugs).to be_empty
      end
    end

    context 'with complex medical text' do
      let(:text) { "Intravenous azithromycin-induced ototoxicity was observed." }

      it 'extracts drug from complex medical language' do
        result = predictor.call(text: text)
        
        expect(result.drugs).to be_an(Array)
        expect(result.drugs.map(&:downcase)).to include('azithromycin')
      end
    end

    context 'with drug class names' do
      let(:text) { "Patient experienced bradycardia after beta-blocker administration." }

      it 'handles drug classes appropriately' do
        result = predictor.call(text: text)
        
        expect(result.drugs).to be_an(Array)
        # Should extract either specific drug name or class
        expect(result.drugs.first).to match(/beta.blocker|metoprolol|atenolol/i) if result.drugs.any?
      end
    end
  end

  # Signature structure is tested through functional usage above
end