# frozen_string_literal: true

# Metrics for evaluating binary classification performance
class ClassificationMetrics
  # Calculate confusion matrix for binary classification
  def self.confusion_matrix(predictions, ground_truth)
    tp = fp = tn = fn = 0

    predictions.zip(ground_truth).each do |pred, actual|
      case [actual, pred]
      when [true, true]   then tp += 1
      when [false, true]  then fp += 1
      when [false, false] then tn += 1
      when [true, false]  then fn += 1
      end
    end

    { tp: tp, fp: fp, tn: tn, fn: fn }
  end

  # Calculate Wilson score interval for confidence intervals  
  def self.wilson_score_interval(successes, trials, confidence_level = 0.95)
    return [0.0, 0.0] if trials.zero?
    
    z = confidence_level == 0.95 ? 1.96 : 2.576  # 95% or 99% confidence
    p_hat = successes.to_f / trials
    
    denominator = 1 + (z**2 / trials)
    center = (p_hat + z**2 / (2 * trials)) / denominator
    margin = z * Math.sqrt((p_hat * (1 - p_hat) + z**2 / (4 * trials)) / trials) / denominator
    
    [(center - margin).clamp(0.0, 1.0), (center + margin).clamp(0.0, 1.0)]
  end

  # Calculate all classification metrics with confidence intervals
  def self.calculate_metrics(predictions, ground_truth)
    cm = confusion_matrix(predictions, ground_truth)
    
    total = cm[:tp] + cm[:fp] + cm[:tn] + cm[:fn]
    return { accuracy: 0.0, precision: 0.0, recall: 0.0, f1: 0.0, specificity: 0.0 } if total.zero?

    accuracy = (cm[:tp] + cm[:tn]).to_f / total
    
    # Handle division by zero
    precision = (cm[:tp] + cm[:fp]).zero? ? 0.0 : cm[:tp].to_f / (cm[:tp] + cm[:fp])
    recall = (cm[:tp] + cm[:fn]).zero? ? 0.0 : cm[:tp].to_f / (cm[:tp] + cm[:fn])
    specificity = (cm[:tn] + cm[:fp]).zero? ? 0.0 : cm[:tn].to_f / (cm[:tn] + cm[:fp])
    
    f1 = (precision + recall).zero? ? 0.0 : 2 * precision * recall / (precision + recall)

    # Calculate 95% confidence intervals
    accuracy_ci = wilson_score_interval(cm[:tp] + cm[:tn], total)
    precision_ci = (cm[:tp] + cm[:fp]).zero? ? [0.0, 0.0] : wilson_score_interval(cm[:tp], cm[:tp] + cm[:fp])
    recall_ci = (cm[:tp] + cm[:fn]).zero? ? [0.0, 0.0] : wilson_score_interval(cm[:tp], cm[:tp] + cm[:fn])
    specificity_ci = (cm[:tn] + cm[:fp]).zero? ? [0.0, 0.0] : wilson_score_interval(cm[:tn], cm[:tn] + cm[:fp])

    {
      accuracy: accuracy,
      precision: precision,
      recall: recall,
      f1: f1,
      specificity: specificity,
      confusion_matrix: cm,
      total_examples: total,
      confidence_intervals: {
        accuracy: accuracy_ci,
        precision: precision_ci,
        recall: recall_ci,
        specificity: specificity_ci
      }
    }
  end

  # Medical-specific safety metrics
  def self.medical_safety_metrics(predictions, ground_truth)
    cm = confusion_matrix(predictions, ground_truth)
    
    # False Negative Rate - critical for medical applications
    fnr = (cm[:tp] + cm[:fn]).zero? ? 0.0 : cm[:fn].to_f / (cm[:tp] + cm[:fn])
    
    # Positive Predictive Value (same as precision)
    ppv = (cm[:tp] + cm[:fp]).zero? ? 0.0 : cm[:tp].to_f / (cm[:tp] + cm[:fp])
    
    # Negative Predictive Value
    npv = (cm[:tn] + cm[:fn]).zero? ? 0.0 : cm[:tn].to_f / (cm[:tn] + cm[:fn])
    
    # Matthews Correlation Coefficient - good for imbalanced data
    numerator = (cm[:tp] * cm[:tn]) - (cm[:fp] * cm[:fn])
    denominator = Math.sqrt((cm[:tp] + cm[:fp]) * (cm[:tp] + cm[:fn]) * (cm[:tn] + cm[:fp]) * (cm[:tn] + cm[:fn]))
    mcc = denominator.zero? ? 0.0 : numerator.to_f / denominator

    {
      false_negative_rate: fnr,
      positive_predictive_value: ppv,
      negative_predictive_value: npv,
      matthews_correlation: mcc,
      missed_ades: cm[:fn],
      false_alarms: cm[:fp]
    }
  end

  # Print comprehensive classification report
  def self.print_metrics(metrics, title, safety_metrics = nil)
    puts "\n📊 #{title}"
    puts "=" * 50
    
    cm = metrics[:confusion_matrix]
    puts "Confusion Matrix:"
    puts "                Predicted"
    puts "              No ADE  ADE"
    puts "Actual No ADE    #{cm[:tn].to_s.rjust(3)}  #{cm[:fp].to_s.rjust(3)}"
    puts "       ADE       #{cm[:fn].to_s.rjust(3)}  #{cm[:tp].to_s.rjust(3)}"
    puts ""
    
    puts "Performance Metrics:"
    puts "Accuracy:   #{(metrics[:accuracy] * 100).round(2)}%"
    puts "Precision:  #{(metrics[:precision] * 100).round(2)}%"
    puts "Recall:     #{(metrics[:recall] * 100).round(2)}%"
    puts "F1 Score:   #{(metrics[:f1] * 100).round(2)}%"
    puts "Specificity: #{(metrics[:specificity] * 100).round(2)}%"
    
    if safety_metrics
      puts "\nMedical Safety Metrics:"
      puts "False Negative Rate: #{(safety_metrics[:false_negative_rate] * 100).round(2)}% (missed ADEs)"
      puts "Missed ADEs: #{safety_metrics[:missed_ades]} cases"
      puts "False Alarms: #{safety_metrics[:false_alarms]} cases"
      puts "Matthews Correlation: #{safety_metrics[:matthews_correlation].round(3)}"
      
      # Safety warnings
      if safety_metrics[:false_negative_rate] > 0.2
        puts "⚠️  HIGH FALSE NEGATIVE RATE - Missing too many ADEs!"
      elsif safety_metrics[:false_negative_rate] > 0.1
        puts "⚠️  Moderate false negative rate - room for improvement"
      else
        puts "✅ Low false negative rate - good safety profile"
      end
    end
    
    # Overall assessment
    if metrics[:f1] > 0.8 && (safety_metrics.nil? || safety_metrics[:false_negative_rate] < 0.15)
      puts "\n✅ Excellent performance for medical application!"
    elsif metrics[:f1] > 0.7
      puts "\n✅ Good performance"
    elsif metrics[:f1] > 0.6
      puts "\n⚠️  Needs improvement"
    else
      puts "\n❌ Poor performance - not suitable for production"
    end
  end
end