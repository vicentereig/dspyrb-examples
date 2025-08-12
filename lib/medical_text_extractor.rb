# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

# Signature for extracting medical information from raw text
class MedicalTextExtractor < DSPy::Signature
  description "Extract medical information from raw clinical text"
  
  input do
    const :text, String, description: "Raw medical text from patient report or clinical note"
  end
  
  output do
    const :patient_report, String, description: "Cleaned and formatted patient report text"
    const :medications, T::Array[String], description: "List of medications extracted from the text (include brand names, generic names, abbreviations like MTX, 5-FU, TMP-SMX)"
    const :symptoms, T::Array[String], description: "List of symptoms, side effects, or adverse reactions mentioned (nausea, headache, rash, pain, dysfunction, toxicity, etc.)"
  end
end

# Chain that combines extraction and prediction
class ADEPipelinePredictor
  attr_reader :extractor, :predictor
  
  def initialize
    require_relative 'ade_predictor'
    require_relative 'baseline_predictor'
    
    @extractor = DSPy::ChainOfThought.new(MedicalTextExtractor)
    @predictor = BaselinePredictor.new
  end
  
  def predict(raw_text)
    # Step 1: Extract structured information from raw text
    extraction_result = if raw_text.is_a?(Hash)
      # If we already have structured input, use it
      if raw_text[:patient_report] && raw_text[:medications]
        raw_text
      else
        # Extract from text field
        text = raw_text[:text] || raw_text['text'] || raw_text.to_s
        @extractor.call(text: text)
      end
    else
      # Raw string input
      @extractor.call(text: raw_text.to_s)
    end
    
    # Step 2: Make ADE prediction using extracted information
    structured_input = if extraction_result.respond_to?(:patient_report)
      symptoms = extraction_result.symptoms
      symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
      
      {
        patient_report: extraction_result.patient_report || '',
        medications: extraction_result.medications || [],
        symptoms: symptoms
      }
    elsif extraction_result.is_a?(Hash)
      symptoms = extraction_result[:symptoms] || extraction_result['symptoms'] || []
      symptoms = symptoms.is_a?(String) ? [symptoms].reject(&:empty?) : (symptoms || [])
      
      {
        patient_report: extraction_result[:patient_report] || extraction_result['patient_report'] || '',
        medications: extraction_result[:medications] || extraction_result['medications'] || [],
        symptoms: symptoms
      }
    else
      # Fallback for unexpected formats
      {
        patient_report: raw_text.to_s,
        medications: [],
        symptoms: []
      }
    end
    
    @predictor.predict(structured_input)
  rescue StandardError => e
    puts "Pipeline prediction error: #{e.message}"
    # Return safe default
    {
      ade_status: ADEPredictor::ADEStatus::NoADE,
      confidence: 0.0,
      drug_symptom_pairs: []
    }
  end
  
  def predict_batch(inputs)
    inputs.map { |input| predict(input) }
  end
  
  # Evaluate performance against test examples
  def evaluate_performance(test_examples)
    require_relative 'evaluation_metrics'
    
    # Extract inputs from examples (might be raw text)
    inputs = test_examples.map { |ex| ex.input_values[:text] || ex.input_values }
    
    # Make predictions
    predictions = predict_batch(inputs)
    
    # Use EvaluationMetrics to calculate performance
    EvaluationMetrics.evaluate_batch(test_examples, predictions)
  end
end