# frozen_string_literal: true

require 'dspy'

# DSPy.rb-native evaluation metrics for medical ADE detection
module DSPyMedicalMetrics
  # Medical ADE detection metric focused on recall (medical safety)
  # Returns a DSPy-compatible metric function
  def self.ade_detection_metric
    lambda do |example, prediction, _trace|
      # Extract expected and predicted values
      expected = example.expected
      
      # Handle both pipeline formats
      predicted_has_ade = if prediction.respond_to?(:has_ade)
        prediction.has_ade
      elsif prediction.is_a?(Hash)
        prediction[:has_ade]
      else
        # Fallback for direct prediction objects
        prediction.respond_to?(:has_ade) ? prediction.has_ade : false
      end
      
      expected_has_ade = expected.has_ade
      
      # Medical safety: Heavily penalize false negatives (missed ADEs)
      if expected_has_ade && !predicted_has_ade
        # False negative - critical medical error
        { 
          score: 0.0, 
          details: {
            type: 'false_negative',
            expected: true,
            predicted: false,
            medical_risk: 'high'
          }
        }
      elsif !expected_has_ade && predicted_has_ade
        # False positive - less critical but still wrong
        { 
          score: 0.3, 
          details: {
            type: 'false_positive',
            expected: false,
            predicted: true,
            medical_risk: 'low'
          }
        }
      elsif expected_has_ade && predicted_has_ade
        # True positive - correct ADE detection
        { 
          score: 1.0, 
          details: {
            type: 'true_positive',
            expected: true,
            predicted: true,
            medical_risk: 'none'
          }
        }
      else
        # True negative - correct non-ADE
        { 
          score: 1.0, 
          details: {
            type: 'true_negative',
            expected: false,
            predicted: false,
            medical_risk: 'none'
          }
        }
      end
    end
  end
  
  # Balanced medical metric that considers both precision and recall
  def self.balanced_ade_metric
    lambda do |example, prediction, _trace|
      expected = example.expected
      
      predicted_has_ade = if prediction.respond_to?(:has_ade)
        prediction.has_ade
      elsif prediction.is_a?(Hash)
        prediction[:has_ade]
      else
        false
      end
      
      expected_has_ade = expected.has_ade
      
      # Standard classification accuracy
      score = (expected_has_ade == predicted_has_ade) ? 1.0 : 0.0
      
      {
        score: score,
        details: {
          expected: expected_has_ade,
          predicted: predicted_has_ade,
          correct: score == 1.0
        }
      }
    end
  end
  
  # Confidence-aware metric that considers prediction confidence
  def self.confidence_aware_metric(confidence_threshold: 0.7)
    lambda do |example, prediction, _trace|
      expected = example.expected
      
      predicted_has_ade = if prediction.respond_to?(:has_ade)
        prediction.has_ade
      elsif prediction.is_a?(Hash)
        prediction[:has_ade]
      else
        false
      end
      
      confidence = if prediction.respond_to?(:confidence)
        prediction.confidence
      elsif prediction.is_a?(Hash) && prediction[:confidence]
        prediction[:confidence]
      else
        1.0  # Default high confidence if not available
      end
      
      expected_has_ade = expected.has_ade
      correct = (expected_has_ade == predicted_has_ade)
      
      # Penalize low confidence predictions
      confidence_penalty = confidence < confidence_threshold ? 0.5 : 1.0
      base_score = correct ? 1.0 : 0.0
      final_score = base_score * confidence_penalty
      
      {
        score: final_score,
        details: {
          expected: expected_has_ade,
          predicted: predicted_has_ade,
          confidence: confidence,
          correct: correct,
          confidence_penalty: confidence_penalty
        }
      }
    end
  end
  
  # Comprehensive medical evaluation that calculates multiple metrics
  def self.comprehensive_medical_metric
    lambda do |example, prediction, _trace|
      expected = example.expected
      
      predicted_has_ade = if prediction.respond_to?(:has_ade)
        prediction.has_ade
      elsif prediction.is_a?(Hash)
        prediction[:has_ade]
      else
        false
      end
      
      confidence = if prediction.respond_to?(:confidence)
        prediction.confidence
      elsif prediction.is_a?(Hash) && prediction[:confidence]
        prediction[:confidence]
      else
        0.5  # Default medium confidence
      end
      
      expected_has_ade = expected.has_ade
      
      # Simple binary correctness score
      correct = (expected_has_ade == predicted_has_ade)
      
      {
        score: correct ? 1.0 : 0.0,
        details: {
          expected: expected_has_ade,
          predicted: predicted_has_ade,
          confidence: confidence,
          correct: correct
        }
      }
    end
  end
end