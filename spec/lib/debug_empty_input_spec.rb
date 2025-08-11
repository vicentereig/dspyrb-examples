# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_predictor'

RSpec.describe "Debug Empty Input" do
  let(:predictor) { DSPy::Predict.new(ADEPredictor) }
  
  it 'tests empty input within RSpec/VCR environment' do
    empty_input = {
      patient_report: "",
      medications: [],
      symptoms: ""
    }
    
    begin
      result = predictor.call(**empty_input)
      puts "✅ Empty input succeeded in test: #{result.ade_status}"
    rescue => e
      puts "❌ Empty input failed in test: #{e.message}"
      puts "Error class: #{e.class}"
    end
  end
  
  it 'tests empty input with VCR cassette', vcr: { cassette_name: 'debug/empty_input' } do
    empty_input = {
      patient_report: "",
      medications: [],
      symptoms: ""
    }
    
    begin
      result = predictor.call(**empty_input)
      puts "✅ Empty input with VCR succeeded: #{result.ade_status}"
    rescue => e
      puts "❌ Empty input with VCR failed: #{e.message}"
      puts "Error class: #{e.class}"
    end
  end
end