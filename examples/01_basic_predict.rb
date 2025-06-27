#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 1: Basic Prediction with DSPy.rb
# This demonstrates the simplest form of DSPy usage with structured output

require_relative '../setup'

class SentimentClassify < DSPy::Signature
  description "Classify sentiment of a given sentence."
  
  class Sentiment < T::Enum
    enums do
      Positive = new('positive')
      Negative = new('negative') 
      Neutral = new('neutral')
    end
  end
  
  input do
    const :sentence, String
  end
  
  output do
    const :sentiment, Sentiment
    const :confidence, Float
  end
end

def run_basic_predict_example
  puts "🔮 Basic Prediction Example"
  puts "=" * 50
  
  # Create predictor
  classify = DSPy::Predict.new(SentimentClassify)
  
  test_sentences = [
    "This book was absolutely amazing and I loved every page!",
    "I hate waiting in long lines at the store.",
    "The weather is okay today, nothing special.",
    "The customer service was terrible and unhelpful.",
    "I'm feeling quite neutral about this decision."
  ]
  
  test_sentences.each_with_index do |sentence, i|
    puts "\n#{i+1}. Testing: \"#{sentence}\""
    
    begin
      result = classify.call(sentence: sentence)
      puts "   Sentiment: #{result.sentiment}"
      puts "   Confidence: #{(result.confidence * 100).round(1)}%"
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  puts "\n✅ Basic Prediction example completed!"
end

if __FILE__ == $0
  configure_dspy
  run_basic_predict_example
end
