# frozen_string_literal: true

require 'dspy'
require_relative '../signatures/ade_direct_classifier'

# Single-signature ADE detection pipeline
# Direct end-to-end approach: text -> ADE classification
class ADEDirectPipeline
  attr_reader :ade_classifier

  def initialize
    @ade_classifier = DSPy::Predict.new(ADEDirectClassifier)
  end

  # Process text through direct classification
  def predict(text)
    raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.strip.empty?
    
    begin
      # Single API call for end-to-end prediction
      result = @ade_classifier.call(text: text)
      
      # Validate result format
      unless [TrueClass, FalseClass].include?(result.has_ade.class)
        raise StandardError, "Classifier returned invalid has_ade: #{result.has_ade.class}"
      end
      
      unless result.confidence.is_a?(Numeric) && 
             result.confidence >= 0.0 && 
             result.confidence <= 1.0
        raise StandardError, "Classifier returned invalid confidence: #{result.confidence}"
      end
      
      unless result.reasoning.is_a?(String)
        raise StandardError, "Classifier returned invalid reasoning: #{result.reasoning.class}"
      end

      {
        text: text,
        has_ade: result.has_ade,
        confidence: result.confidence,
        reasoning: result.reasoning,
        api_calls: 1,  # Track API usage for cost comparison
        error: nil
      }
      
    rescue StandardError => e
      # Return error information instead of silent failure
      {
        text: text,
        has_ade: false,  # Conservative default for safety
        confidence: 0.0,
        reasoning: "Error occurred during classification",
        api_calls: 1,
        error: {
          message: e.message,
          type: e.class.name,
          timestamp: Time.now.iso8601
        }
      }
    end
  end

  # Batch prediction for multiple texts
  def predict_batch(texts)
    texts.map { |text| predict(text) }
  end
end