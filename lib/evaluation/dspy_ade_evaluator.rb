# frozen_string_literal: true

require 'dspy'
require_relative 'dspy_medical_metrics'

# DSPy.rb-native ADE pipeline evaluator
class DSPyADEEvaluator
  attr_reader :results

  def initialize(pipeline_class, metric: nil)
    @pipeline_class = pipeline_class
    @metric = metric || DSPyMedicalMetrics.comprehensive_medical_metric
    @results = {}
  end

  # Convert our dataset format to DSPy examples
  def prepare_dspy_examples(raw_examples, signature_class = nil)
    # Create a simple signature class for our ADE detection task
    unless signature_class
      signature_class = Class.new(DSPy::Signature) do
        description "ADE detection from medical text"
        
        input do
          const :text, String, description: "Medical text to analyze"
        end
        
        output do
          const :has_ade, T::Boolean, description: "Whether text describes an ADE"
        end
      end
    end
    
    raw_examples.map.with_index do |raw_example, i|
      input_values = raw_example.respond_to?(:input_values) ? raw_example.input_values : raw_example[:input]
      expected_values = raw_example.respond_to?(:expected_values) ? raw_example.expected_values : raw_example[:expected]
      
      # Create DSPy::Example with proper constructor parameters
      DSPy::Example.new(
        signature_class: signature_class,
        input: {
          text: input_values[:text]
        },
        expected: {
          has_ade: expected_values[:has_ade]
        },
        id: "ade_example_#{i}"
      )
    end
  end

  # Create a DSPy-compatible program wrapper
  def create_program_wrapper(pipeline)
    # Create a class that implements the DSPy program interface
    wrapper_class = Class.new do
      def initialize(pipeline)
        @pipeline = pipeline
      end
      
      def call(input_values)
        text = input_values[:text] || input_values.text
        result = @pipeline.predict(text)
        
        # Return a result object that responds to the expected methods
        result_class = Struct.new(:has_ade, :confidence, :reasoning, :api_calls, :error) do
          def initialize(has_ade:, confidence: 0.5, reasoning: "", api_calls: 1, error: nil)
            super(has_ade, confidence, reasoning, api_calls, error)
          end
        end
        
        result_class.new(
          has_ade: result[:has_ade],
          confidence: result[:confidence] || 0.5,
          reasoning: result[:reasoning] || "",
          api_calls: result[:api_calls] || 1,
          error: result[:error]
        )
      end
      
      # Make it respond to DSPy program interface
      def forward(input_values)
        call(input_values)
      end
    end
    
    wrapper_class.new(pipeline)
  end

  # Run comprehensive evaluation using DSPy::Evaluate
  def evaluate(raw_examples, sample_size: nil, num_threads: 1, max_errors: 5)
    # Sample if requested
    examples_to_test = sample_size ? raw_examples.first(sample_size) : raw_examples
    
    # Convert to DSPy examples
    dspy_examples = prepare_dspy_examples(examples_to_test)
    
    # Create pipeline instance and wrapper
    pipeline = @pipeline_class.new
    program = create_program_wrapper(pipeline)
    
    puts "🧪 Running DSPy.rb evaluation on #{examples_to_test.size} examples"
    puts "   Pipeline: #{@pipeline_class.name}"
    puts "   Threads: #{num_threads}"
    puts "   Max errors: #{max_errors}"
    
    # Create DSPy evaluator
    evaluator = DSPy::Evaluate.new(
      program,
      metric: @metric,
      num_threads: num_threads,
      max_errors: max_errors,
      provide_traceback: true
    )
    
    # Run evaluation
    start_time = Time.now
    evaluation_result = evaluator.evaluate(dspy_examples)
    evaluation_time = Time.now - start_time
    
    # Process results
    @results = process_evaluation_results(evaluation_result, examples_to_test, evaluation_time)
    
    @results
  end

  # Print comprehensive evaluation results
  def print_results(title = "DSPy.rb ADE Evaluation Results")
    return unless @results
    
    puts "\n📊 #{title}"
    puts "=" * 60
    
    puts "DSPy.rb Native Metrics:"
    puts "  Overall Score: #{(@results[:dspy_score] * 100).round(1)}%"
    puts "  Pass Rate: #{(@results[:dspy_pass_rate] * 100).round(1)}%"
    
    puts "\nClassification Performance:"
    puts "  Accuracy:  #{(@results[:accuracy] * 100).round(1)}%"
    puts "  Precision: #{(@results[:precision] * 100).round(1)}%"
    puts "  Recall:    #{(@results[:recall] * 100).round(1)}%"
    puts "  F1 Score:  #{(@results[:f1] * 100).round(1)}%"
    
    puts "\nMedical Safety Analysis:"
    puts "  False Negative Rate: #{(@results[:false_negative_rate] * 100).round(1)}%"
    puts "  Missed ADEs: #{@results[:missed_ades]} cases"
    puts "  False Alarms: #{@results[:false_alarms]} cases"
    
    puts "\nConfidence Analysis:"
    puts "  Average Confidence: #{(@results[:average_confidence] * 100).round(1)}%"
    puts "  Low Confidence Cases: #{@results[:low_confidence_predictions]}"
    
    puts "\nConfusion Matrix:"
    cm = @results[:confusion_matrix]
    puts "                 Predicted"
    puts "               No ADE  ADE"
    puts "Actual No ADE    #{cm[:tn].to_s.rjust(3)}  #{cm[:fp].to_s.rjust(3)}"
    puts "       ADE       #{cm[:fn].to_s.rjust(3)}  #{cm[:tp].to_s.rjust(3)}"
    
    # Show false negatives if any
    if @results[:false_negatives].any?
      puts "\n❌ False Negatives (Missed ADEs):"
      @results[:false_negatives].each_with_index do |fn, i|
        puts "  #{i+1}. Confidence: #{fn[:confidence]} | Text: #{fn[:text]}..."
      end
    end
    
    puts "\nEvaluation completed in #{@results[:evaluation_time].round(2)}s"
  end

  private

  def process_evaluation_results(evaluation_result, original_examples, evaluation_time)
    # Extract detailed metrics from DSPy evaluation results
    individual_results = evaluation_result.results || []
    
    confusion_matrix = { tp: 0, fp: 0, tn: 0, fn: 0 }
    confidence_scores = []
    false_negatives = []
    false_positives = []
    
    individual_results.each_with_index do |result, i|
      # Get expected and predicted values from DSPy result
      expected = result.example.expected.has_ade
      predicted = result.prediction.has_ade
      
      # Determine confusion matrix type
      if predicted && expected
        confusion_matrix[:tp] += 1
      elsif predicted && !expected
        confusion_matrix[:fp] += 1
        text_snippet = result.example.input.text[0..200]
        false_positives << {
          index: i,
          expected: expected,
          predicted: predicted,
          confidence: 0.5,  # Default since we don't have confidence from this format
          text: text_snippet
        }
      elsif !predicted && !expected
        confusion_matrix[:tn] += 1
      else  # !predicted && expected
        confusion_matrix[:fn] += 1
        text_snippet = result.example.input.text[0..200]
        false_negatives << {
          index: i,
          expected: expected,
          predicted: predicted, 
          confidence: 0.5,  # Default since we don't have confidence from this format
          text: text_snippet
        }
      end
      
      confidence_scores << 0.5  # Default confidence since not available in basic format
    end
    
    # Calculate comprehensive metrics
    tp, fp, tn, fn = confusion_matrix.values
    total = tp + fp + tn + fn
    total_positives = tp + fn
    
    accuracy = total > 0 ? (tp + tn).to_f / total : 0.0
    precision = (tp + fp) > 0 ? tp.to_f / (tp + fp) : 0.0
    recall = total_positives > 0 ? tp.to_f / total_positives : 0.0
    f1 = (precision + recall) > 0 ? 2 * precision * recall / (precision + recall) : 0.0
    
    # Medical safety metrics
    false_negative_rate = total_positives > 0 ? fn.to_f / total_positives : 0.0
    
    # Confidence analysis
    avg_confidence = confidence_scores.empty? ? 0.0 : confidence_scores.sum / confidence_scores.size
    low_confidence_count = confidence_scores.count { |c| c < 0.6 }
    
    {
      # DSPy evaluation results
      dspy_score: (evaluation_result.pass_rate || 0.0),
      dspy_pass_rate: (evaluation_result.pass_rate || 0.0),
      
      # Traditional ML metrics
      confusion_matrix: confusion_matrix,
      accuracy: accuracy,
      precision: precision,
      recall: recall,
      f1: f1,
      
      # Medical safety metrics
      false_negative_rate: false_negative_rate,
      missed_ades: fn,
      false_alarms: fp,
      
      # Confidence analysis
      average_confidence: avg_confidence,
      low_confidence_predictions: low_confidence_count,
      
      # Error analysis
      false_negatives: false_negatives,
      false_positives: false_positives,
      
      # Metadata
      total_examples: total,
      evaluation_time: evaluation_time,
      timestamp: Time.now.iso8601
    }
  end

end