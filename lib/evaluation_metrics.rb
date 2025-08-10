# frozen_string_literal: true

require_relative 'ade_predictor'

class EvaluationMetrics
  class << self
    # Calculate precision: TP / (TP + FP)
    def calculate_precision(true_positives, false_positives)
      total_predicted_positive = true_positives + false_positives
      return 0.0 if total_predicted_positive == 0
      
      true_positives.to_f / total_predicted_positive
    end
    
    # Calculate recall: TP / (TP + FN)
    def calculate_recall(true_positives, false_negatives)
      total_actual_positive = true_positives + false_negatives
      return 0.0 if total_actual_positive == 0
      
      true_positives.to_f / total_actual_positive
    end
    
    # Calculate F1 score: harmonic mean of precision and recall
    def calculate_f1_score(precision, recall)
      return 0.0 if precision == 0 || recall == 0
      
      2.0 * (precision * recall) / (precision + recall)
    end
    
    # Generate confusion matrix for multi-class classification
    def confusion_matrix(predictions, actuals)
      raise ArgumentError, "Predictions and actuals must have same length" if predictions.size != actuals.size
      
      # Initialize matrix structure
      all_classes = (predictions + actuals).uniq
      matrix = Hash.new { |h, k| h[k] = Hash.new(0) }
      
      # Fill confusion matrix
      predictions.zip(actuals).each do |pred, actual|
        matrix[pred][actual] += 1
      end
      
      # Calculate aggregated metrics for binary classification
      # Treat NoADE as negative, any ADE as positive
      tp = 0  # True positives (correctly predicted ADE)
      fp = 0  # False positives (incorrectly predicted ADE)
      tn = 0  # True negatives (correctly predicted no ADE)
      fn = 0  # False negatives (missed ADE)
      
      predictions.zip(actuals).each do |pred, actual|
        pred_is_ade = pred != ADEPredictor::ADEStatus::NoADE
        actual_is_ade = actual != ADEPredictor::ADEStatus::NoADE
        
        if pred_is_ade && actual_is_ade
          tp += 1
        elsif pred_is_ade && !actual_is_ade
          fp += 1
        elsif !pred_is_ade && !actual_is_ade
          tn += 1
        else  # !pred_is_ade && actual_is_ade
          fn += 1
        end
      end
      
      # Calculate per-class metrics
      per_class = {}
      all_classes.each do |cls|
        # For this class as positive, all others as negative
        class_tp = matrix[cls][cls]
        class_fp = all_classes.sum { |other| other == cls ? 0 : matrix[cls][other] }
        class_fn = all_classes.sum { |other| other == cls ? 0 : matrix[other][cls] }
        
        class_precision = calculate_precision(class_tp, class_fp)
        class_recall = calculate_recall(class_tp, class_fn)
        class_f1 = calculate_f1_score(class_precision, class_recall)
        
        per_class[cls] = {
          precision: class_precision,
          recall: class_recall,
          f1: class_f1
        }
      end
      
      {
        matrix: matrix,
        tp: tp,
        fp: fp,
        tn: tn,
        fn: fn,
        per_class: per_class
      }
    end
    
    # Create a metric function for DSPy::Evaluate
    def create_dspy_metric(confidence_threshold: 0.0)
      proc do |example, prediction|
        # Handle nil or invalid predictions
        next false if prediction.nil? || !prediction.is_a?(Hash)
        next false unless prediction[:ade_status] && prediction[:confidence]
        
        # Check confidence threshold
        next false if prediction[:confidence] < confidence_threshold
        
        # Compare ADE status
        expected_status = example.expected_values[:ade_status]
        predicted_status = prediction[:ade_status]
        
        expected_status == predicted_status
      end
    end
    
    # Evaluate a batch of predictions against examples
    def evaluate_batch(examples, predictions)
      raise ArgumentError, "Examples and predictions must have same length" if examples.size != predictions.size
      
      # Extract actual and predicted ADE statuses
      actuals = examples.map { |ex| ex.expected_values[:ade_status] }
      preds = predictions.map { |p| p[:ade_status] }
      
      # Get confusion matrix and metrics
      cm = confusion_matrix(preds, actuals)
      
      # Calculate overall metrics (treating any ADE as positive)
      precision = calculate_precision(cm[:tp], cm[:fp])
      recall = calculate_recall(cm[:tp], cm[:fn])
      f1 = calculate_f1_score(precision, recall)
      
      # Calculate accuracy
      correct = preds.zip(actuals).count { |pred, actual| pred == actual }
      accuracy = correct.to_f / examples.size
      
      {
        precision: precision,
        recall: recall,
        f1: f1,
        accuracy: accuracy,
        confusion_matrix: cm,
        total_examples: examples.size,
        correct_predictions: correct
      }
    end
  end
end