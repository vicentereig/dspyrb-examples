# frozen_string_literal: true

require 'dspy'
require_relative '../signatures/drug_extractor'
require_relative '../signatures/effect_extractor'
require_relative '../signatures/ade_classifier'

# Three-stage ADE detection pipeline
# Stage 1: Extract drugs from text
# Stage 2: Extract adverse effects from text  
# Stage 3: Classify if ADE is present based on drugs and effects
class ADEPipeline
  attr_reader :drug_extractor, :effect_extractor, :ade_classifier

  def initialize
    @drug_extractor = DSPy::Predict.new(DrugExtractor)
    @effect_extractor = DSPy::Predict.new(EffectExtractor)
    @ade_classifier = DSPy::Predict.new(ADEClassifier)
  end

  # Process text through the full pipeline
  def predict(text)
    raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.strip.empty?
    
    begin
      # Stage 1: Extract drugs
      drug_result = @drug_extractor.call(text: text)
      drugs = drug_result.drugs
      
      # Validate drug extraction result
      unless drugs.is_a?(Array)
        raise StandardError, "Drug extractor returned invalid format: #{drugs.class}"
      end
      
      # Stage 2: Extract effects
      effect_result = @effect_extractor.call(text: text)
      effects = effect_result.effects
      
      # Validate effect extraction result
      unless effects.is_a?(Array)
        raise StandardError, "Effect extractor returned invalid format: #{effects.class}"
      end

      # Stage 3: Classify ADE
      classification_result = @ade_classifier.call(
        text: text,
        drugs: drugs,
        effects: effects
      )
      
      # Validate classification result
      unless [TrueClass, FalseClass].include?(classification_result.has_ade.class)
        raise StandardError, "ADE classifier returned invalid has_ade: #{classification_result.has_ade.class}"
      end
      
      unless classification_result.confidence.is_a?(Numeric) && 
             classification_result.confidence >= 0.0 && 
             classification_result.confidence <= 1.0
        raise StandardError, "ADE classifier returned invalid confidence: #{classification_result.confidence}"
      end

      {
        text: text,
        drugs: drugs,
        effects: effects,
        has_ade: classification_result.has_ade,
        confidence: classification_result.confidence,
        api_calls: 3,
        stages: {
          drug_extraction: drug_result,
          effect_extraction: effect_result,
          classification: classification_result
        },
        error: nil
      }
      
    rescue StandardError => e
      # Return error information instead of silent failure
      {
        text: text,
        drugs: [],
        effects: [],
        has_ade: false,  # Conservative default for safety
        confidence: 0.0,
        api_calls: 3,
        stages: {},
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