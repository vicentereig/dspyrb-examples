#!/usr/bin/env ruby

require 'dotenv/load'
require 'dspy'
require_relative 'lib/data/ade_dataset_loader'
require_relative 'lib/pipeline/ade_direct_pipeline'
require_relative 'lib/evaluation/dspy_medical_metrics'

DSPy.configure do |c|
  c.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])
end

puts "🔍 Debug DSPy.rb Evaluation API"

# Load a small sample
loader = AdeDatasetLoader.new
training_data = loader.prepare_training_data
test_examples = training_data[:classification_examples][:test].first(3)

# Create signature class
signature_class = Class.new(DSPy::Signature) do
  description "ADE detection from medical text"
  
  input do
    const :text, String, description: "Medical text to analyze"
  end
  
  output do
    const :has_ade, T::Boolean, description: "Whether text describes an ADE"
  end
end

# Create DSPy examples
dspy_examples = test_examples.map.with_index do |raw_example, i|
  input_values = raw_example.respond_to?(:input_values) ? raw_example.input_values : raw_example[:input]
  expected_values = raw_example.respond_to?(:expected_values) ? raw_example.expected_values : raw_example[:expected]
  
  DSPy::Example.new(
    signature_class: signature_class,
    input: {
      text: input_values[:text]
    },
    expected: {
      has_ade: expected_values[:has_ade]
    },
    id: "debug_#{i}"
  )
end

puts "Created #{dspy_examples.size} DSPy examples"

# Create simple program wrapper
pipeline = ADEDirectPipeline.new

program_class = Class.new do
  def initialize(pipeline)
    @pipeline = pipeline
  end
  
  def call(input_values)
    result = @pipeline.predict(input_values[:text])
    
    # Return struct with has_ade
    Struct.new(:has_ade).new(result[:has_ade])
  end
  
  def forward(input_values)
    call(input_values)
  end
end

program = program_class.new(pipeline)

# Test simple metric
simple_metric = lambda do |example, prediction, _trace|
  expected = example.expected[:has_ade]
  predicted = prediction.has_ade
  
  {
    score: expected == predicted ? 1.0 : 0.0,
    details: {
      expected: expected,
      predicted: predicted,
      correct: expected == predicted
    }
  }
end

puts "\nTesting DSPy::Evaluate..."

# Create evaluator
evaluator = DSPy::Evaluate.new(
  program,
  metric: simple_metric,
  num_threads: 1,
  max_errors: 1
)

# Run evaluation
result = evaluator.evaluate(dspy_examples)

puts "\nEvaluation result type: #{result.class}"
puts "Pass rate: #{result.pass_rate}"
puts "Total examples: #{result.total_examples}"

# Check first result
first_result = result.results.first
puts "\nFirst result type: #{first_result.class}"
puts "First result methods: #{first_result.methods.grep(/\w/).sort}"

puts "\nExample details:"
puts "  Example class: #{first_result.example.class}"
puts "  Example methods: #{first_result.example.methods.grep(/\w/).sort}"
puts "  Example input: #{first_result.example.input}"
puts "  Example expected: #{first_result.example.expected}"

puts "\nPrediction details:"  
puts "  Prediction class: #{first_result.prediction.class}"
puts "  Prediction methods: #{first_result.prediction.methods.grep(/\w/).sort}"
puts "  Prediction has_ade: #{first_result.prediction.has_ade}"