# frozen_string_literal: true

require 'dspy'
require_relative 'ade_predictor'
require_relative 'evaluation_metrics'

class BaselinePredictor
  attr_reader :program, :signature_class
  
  def initialize
    @signature_class = ADEPredictor
    @program = DSPy::Predict.new(@signature_class)
    @token_usage = { total_tokens: 0, input_tokens: 0, output_tokens: 0 }
  end
  
  # Make a single prediction
  def predict(input)
    begin
      # Validate input
      validated_input = validate_and_clean_input(input)
      
      # Make prediction using DSPy
      result = @program.call(**validated_input)
      
      # Track token usage (mock for now)
      update_token_usage(input: validated_input.to_s.length, output: result.to_s.length)
      
      # Convert result to expected format
      format_prediction(result)
      
    rescue StandardError => e
      puts "Error in prediction: #{e.message}"
      # Return a safe default prediction
      {
        ade_status: ADEPredictor::ADEStatus::NoADE,
        confidence: 0.0,
        drug_symptom_pairs: []
      }
    end
  end
  
  # Make predictions for multiple inputs
  def predict_batch(inputs)
    return [] if inputs.empty?
    
    inputs.map { |input| predict(input) }
  end
  
  # Evaluate performance against test examples
  def evaluate_performance(test_examples)
    # Extract inputs from examples
    inputs = test_examples.map { |ex| ex.input_values }
    
    # Make predictions
    predictions = predict_batch(inputs)
    
    # Use EvaluationMetrics to calculate performance
    EvaluationMetrics.evaluate_batch(test_examples, predictions)
  end
  
  # Token usage tracking
  def token_usage
    @token_usage.dup
  end
  
  def reset_token_usage
    @token_usage = { total_tokens: 0, input_tokens: 0, output_tokens: 0 }
  end
  
  private
  
  def validate_and_clean_input(input)
    {
      patient_report: input[:patient_report].to_s,
      medications: Array(input[:medications]).compact.map(&:to_s),
      symptoms: input[:symptoms].to_s
    }
  end
  
  def format_prediction(result)
    # Handle the case where result might be a structured response
    if result.respond_to?(:ade_status)
      ade_status = result.ade_status
      confidence = result.respond_to?(:confidence) ? result.confidence : 0.8
      drug_symptom_pairs = result.respond_to?(:drug_symptom_pairs) ? result.drug_symptom_pairs : []
    else
      # Parse from hash if that's what we get back
      ade_status = parse_ade_status(result[:ade_status]) if result.is_a?(Hash)
      confidence = result[:confidence] || 0.8
      drug_symptom_pairs = parse_drug_symptom_pairs(result[:drug_symptom_pairs]) if result.is_a?(Hash)
    end
    
    # Ensure we have valid values
    ade_status ||= ADEPredictor::ADEStatus::NoADE
    confidence ||= 0.8
    drug_symptom_pairs ||= []
    
    # Ensure confidence is in valid range
    confidence = [[confidence, 0.0].max, 1.0].min
    
    {
      ade_status: ade_status,
      confidence: confidence.to_f,
      drug_symptom_pairs: drug_symptom_pairs
    }
  end
  
  def parse_ade_status(status_value)
    case status_value
    when ADEPredictor::ADEStatus
      status_value
    when String, Symbol
      case status_value.to_s.downcase
      when 'no_adverse_event', 'noade', 'none', 'no'
        ADEPredictor::ADEStatus::NoADE
      when 'mild_adverse_event', 'mildade', 'mild'
        ADEPredictor::ADEStatus::MildADE
      when 'severe_adverse_event', 'severeade', 'severe'
        ADEPredictor::ADEStatus::SevereADE
      else
        ADEPredictor::ADEStatus::NoADE
      end
    else
      ADEPredictor::ADEStatus::NoADE
    end
  end
  
  def parse_drug_symptom_pairs(pairs_data)
    return [] unless pairs_data
    
    Array(pairs_data).map do |pair|
      if pair.is_a?(ADEPredictor::DrugSymptomPair)
        pair
      elsif pair.is_a?(Hash)
        ADEPredictor::DrugSymptomPair.new(
          drug: pair[:drug] || pair['drug'] || '',
          symptom: pair[:symptom] || pair['symptom'] || ''
        )
      else
        # Skip invalid pairs
        nil
      end
    end.compact
  end
  
  def update_token_usage(input:, output:)
    # Mock token calculation based on character count
    # In real implementation, would get from LLM response metadata
    input_tokens = (input / 4.0).ceil  # Rough approximation: 4 chars per token
    output_tokens = (output / 4.0).ceil
    
    @token_usage[:input_tokens] += input_tokens
    @token_usage[:output_tokens] += output_tokens
    @token_usage[:total_tokens] = @token_usage[:input_tokens] + @token_usage[:output_tokens]
  end
end