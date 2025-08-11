require 'bundler/setup'
require 'dspy'
require 'dotenv/load'
require_relative 'lib/ade_predictor'

# Test what happens when we send empty inputs to OpenAI
begin
  DSPy.configure do |config|
    config.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
  end

  predictor = DSPy::Predict.new(ADEPredictor)
  
  puts "Testing empty input..."
  empty_input = {
    patient_report: "",
    medications: [],
    symptoms: ""
  }
  
  result = predictor.call(**empty_input)
  puts "✅ Empty input succeeded!"
  puts "Result: #{result.inspect}"
  
rescue => e
  puts "❌ Empty input failed: #{e.message}"
  puts "Error class: #{e.class}"
  
  # Let's also test a minimal valid input
  begin
    puts "\nTesting minimal valid input..."
    minimal_input = {
      patient_report: "No issues reported",
      medications: [],
      symptoms: "none"
    }
    
    result = predictor.call(**minimal_input)
    puts "✅ Minimal input succeeded!"
    puts "Result: #{result.inspect}"
    
  rescue => e2
    puts "❌ Even minimal input failed: #{e2.message}"
  end
end