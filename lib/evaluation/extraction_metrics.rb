# frozen_string_literal: true

# Metrics for evaluating extraction performance (drugs and effects)
class ExtractionMetrics
  # Calculate precision, recall, F1 for extraction tasks using macro-averaging
  def self.calculate_metrics(predictions, ground_truth)
    # Collect all individual precision/recall/f1 scores for macro-averaging
    precision_scores = []
    recall_scores = []
    f1_scores = []
    
    # Also track micro-averaging components
    total_tp = 0
    total_fp = 0  
    total_fn = 0
    valid_examples = 0

    predictions.zip(ground_truth).each do |pred_list, true_list|
      # Handle nil values
      pred_set = Set.new((pred_list || []).map(&:downcase))
      true_set = Set.new((true_list || []).map(&:downcase))

      # Skip if no ground truth (can't calculate metrics)
      next if true_set.empty?

      valid_examples += 1

      # Calculate intersection
      intersection = pred_set & true_set
      
      # Individual example metrics
      tp = intersection.size
      fp = pred_set.size - tp
      fn = true_set.size - tp
      
      # Accumulate for micro-averaging
      total_tp += tp
      total_fp += fp
      total_fn += fn

      # Individual precision/recall for macro-averaging
      precision = pred_set.empty? ? 0.0 : tp.to_f / pred_set.size
      recall = true_set.empty? ? 0.0 : tp.to_f / true_set.size
      f1 = (precision + recall).zero? ? 0.0 : 2 * precision * recall / (precision + recall)
      
      precision_scores << precision
      recall_scores << recall
      f1_scores << f1
    end

    return { precision: 0.0, recall: 0.0, f1: 0.0, valid_examples: 0 } if valid_examples.zero?

    # Macro-averaging (standard for imbalanced data)
    macro_precision = precision_scores.sum / precision_scores.size
    macro_recall = recall_scores.sum / recall_scores.size
    macro_f1 = f1_scores.sum / f1_scores.size
    
    # Micro-averaging for comparison
    micro_precision = total_tp.zero? ? 0.0 : total_tp.to_f / (total_tp + total_fp)
    micro_recall = total_tp.zero? ? 0.0 : total_tp.to_f / (total_tp + total_fn)
    micro_f1 = (micro_precision + micro_recall).zero? ? 0.0 : 2 * micro_precision * micro_recall / (micro_precision + micro_recall)

    {
      # Primary metrics (macro-averaged - standard for medical ML)
      precision: macro_precision,
      recall: macro_recall,
      f1: macro_f1,
      
      # Additional metrics for transparency
      micro_precision: micro_precision,
      micro_recall: micro_recall,
      micro_f1: micro_f1,
      
      valid_examples: valid_examples,
      total_examples: predictions.size,
      averaging_method: 'macro'
    }
  end

  # Detailed analysis of extraction errors
  def self.analyze_errors(predictions, ground_truth, texts = nil)
    errors = {
      false_positives: [],  # Predicted but not in ground truth
      false_negatives: [],  # In ground truth but not predicted
      examples: []
    }

    predictions.zip(ground_truth).each_with_index do |(pred_list, true_list), idx|
      pred_set = Set.new((pred_list || []).map(&:downcase))
      true_set = Set.new((true_list || []).map(&:downcase))

      fp = pred_set - true_set
      fn = true_set - pred_set

      unless fp.empty? && fn.empty?
        example_error = {
          index: idx,
          predicted: pred_list || [],
          ground_truth: true_list || [],
          false_positives: fp.to_a,
          false_negatives: fn.to_a
        }
        
        example_error[:text] = texts[idx] if texts
        errors[:examples] << example_error
      end

      errors[:false_positives].concat(fp.to_a)
      errors[:false_negatives].concat(fn.to_a)
    end

    errors
  end

  # Print formatted metrics report
  def self.print_metrics(metrics, title)
    puts "\n📊 #{title}"
    puts "=" * 50
    puts "Precision: #{(metrics[:precision] * 100).round(2)}%"
    puts "Recall:    #{(metrics[:recall] * 100).round(2)}%"
    puts "F1 Score:  #{(metrics[:f1] * 100).round(2)}%"
    puts "Valid examples: #{metrics[:valid_examples]}/#{metrics[:total_examples]}"
    
    if metrics[:recall] < 0.7
      puts "⚠️  Low recall - many items are being missed"
    end
    
    if metrics[:precision] < 0.7
      puts "⚠️  Low precision - many false positives"
    end
    
    if metrics[:f1] > 0.8
      puts "✅ Excellent performance!"
    elsif metrics[:f1] > 0.7
      puts "✅ Good performance"
    elsif metrics[:f1] > 0.6
      puts "⚠️  Needs improvement"
    else
      puts "❌ Poor performance"
    end
  end
end