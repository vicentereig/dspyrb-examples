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
    @cost_tracking = { total_cost: 0.0, requests: 0, model: 'gpt-4o-mini' }
  end
  
  # Make a single prediction
  def predict(input)
    begin
      # Validate input
      validated_input = validate_and_clean_input(input)
      
      # Make prediction using DSPy
      result = @program.call(**validated_input)
      
      # Track token usage from actual API response if available
      if result.respond_to?(:usage) && result.usage
        update_actual_token_usage(result.usage)
      else
        # Fallback to mock calculation
        update_token_usage(input: validated_input.to_s.length, output: result.to_s.length)
      end
      
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
    @cost_tracking = { total_cost: 0.0, requests: 0, model: 'gpt-4o-mini' }
  end

  # Cost tracking
  def cost_summary
    {
      total_cost: @cost_tracking[:total_cost],
      requests: @cost_tracking[:requests],
      model: @cost_tracking[:model],
      tokens: @token_usage,
      cost_per_1k_input: gpt_4o_mini_input_price,
      cost_per_1k_output: gpt_4o_mini_output_price
    }
  end

  def reset_cost_tracking
    reset_token_usage
  end
  
  private
  
  def validate_and_clean_input(input)
    # Handle symptoms as array since signature expects T::Array[String]
    symptoms = if input[:symptoms].is_a?(Array)
      input[:symptoms].map(&:to_s).compact.reject(&:empty?)
    elsif input[:symptoms].is_a?(String) && !input[:symptoms].empty?
      [input[:symptoms]]
    else
      []
    end
    
    {
      patient_report: input[:patient_report].to_s,
      medications: Array(input[:medications]).compact.map(&:to_s),
      symptoms: symptoms
    }
  end
  
  def format_prediction(result)
    # Handle the case where result might be a structured response
    if result.respond_to?(:ade_status)
      ade_status = result.ade_status
      confidence = result.respond_to?(:confidence) ? result.confidence : 0.8
      drug_symptom_pairs = result.respond_to?(:drug_symptom_pairs) ? parse_drug_symptom_pairs(result.drug_symptom_pairs) : []
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
        # Handle both symbol and string keys, and _type field from LLM responses
        drug = pair[:drug] || pair['drug'] || ''
        symptom = pair[:symptom] || pair['symptom'] || ''
        
        ADEPredictor::DrugSymptomPair.new(
          drug: drug.to_s,
          symptom: symptom.to_s
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
    
    # Update cost tracking
    update_cost_tracking(input_tokens, output_tokens)
  end

  # Update token usage from actual OpenAI API response
  def update_actual_token_usage(usage_data)
    input_tokens = usage_data['prompt_tokens'] || usage_data[:prompt_tokens] || 0
    output_tokens = usage_data['completion_tokens'] || usage_data[:completion_tokens] || 0
    total_tokens = usage_data['total_tokens'] || usage_data[:total_tokens] || (input_tokens + output_tokens)
    
    @token_usage[:input_tokens] += input_tokens
    @token_usage[:output_tokens] += output_tokens
    @token_usage[:total_tokens] += total_tokens
    
    # Update cost tracking with actual usage
    update_cost_tracking(input_tokens, output_tokens)
  end

  # Calculate and update cost based on gpt-4o-mini pricing
  def update_cost_tracking(input_tokens, output_tokens)
    input_cost = (input_tokens / 1000.0) * gpt_4o_mini_input_price
    output_cost = (output_tokens / 1000.0) * gpt_4o_mini_output_price
    request_cost = input_cost + output_cost
    
    @cost_tracking[:total_cost] += request_cost
    @cost_tracking[:requests] += 1
  end

  # GPT-4o-mini pricing (as of 2024)
  def gpt_4o_mini_input_price
    0.00015  # $0.150 per 1M input tokens = $0.00015 per 1K tokens
  end

  def gpt_4o_mini_output_price
    0.0006   # $0.600 per 1M output tokens = $0.0006 per 1K tokens
  end
end