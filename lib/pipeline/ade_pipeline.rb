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
    # Stage 1: Extract drugs
    drug_result = @drug_extractor.call(text: text)
    drugs = drug_result.drugs || []

    # Stage 2: Extract effects
    effect_result = @effect_extractor.call(text: text)
    effects = effect_result.effects || []

    # Stage 3: Classify ADE
    classification_result = @ade_classifier.call(
      text: text,
      drugs: drugs,
      effects: effects
    )

    {
      text: text,
      drugs: drugs,
      effects: effects,
      has_ade: classification_result.has_ade,
      confidence: classification_result.confidence,
      stages: {
        drug_extraction: drug_result,
        effect_extraction: effect_result,
        classification: classification_result
      }
    }
  end

  # Batch prediction for multiple texts
  def predict_batch(texts)
    texts.map { |text| predict(text) }
  end
end