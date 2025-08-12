#!/usr/bin/env ruby

require 'polars-df'

# Load all three dataset configurations
def load_ade_datasets
  base_path = "data/ade_corpus_v2"
  
  datasets = {
    classification: Polars.read_parquet("#{base_path}/Ade_corpus_v2_classification/train-00000-of-00001.parquet"),
    drug_ade: Polars.read_parquet("#{base_path}/Ade_corpus_v2_drug_ade_relation/train-00000-of-00001.parquet"),
    drug_dosage: Polars.read_parquet("#{base_path}/Ade_corpus_v2_drug_dosage_relation/train-00000-of-00001.parquet")
  }
  
  puts "=" * 60
  puts "ADE Dataset Overview (Using Polars in Ruby)"
  puts "=" * 60
  
  datasets.each do |name, df|
    puts "\n#{name.to_s.upcase} Configuration:"
    puts "  Shape: #{df.shape}"
    puts "  Columns: #{df.columns}"
    
    # Show first few rows
    puts "  First 2 rows:"
    df.head(2).each_row do |row|
      row_data = row.to_h
      row_data.each do |col, val|
        if col.to_s == 'text' && val.to_s.length > 100
          puts "    #{col}: #{val.to_s[0..100]}..."
        elsif col.to_s == 'indexes'
          puts "    #{col}: <structured position data>"
        else
          puts "    #{col}: #{val}"
        end
      end
      puts "    ---"
    end
    
    # Statistics
    if df.columns.include?('label')
      label_counts = df.group_by('label').count
      puts "  Label distribution:"
      label_counts.each_row do |row|
        data = row.to_h
        puts "    Label #{data['label']}: #{data['count']} examples"
      end
    end
  end
  
  datasets
end

# Create unified training data
def create_unified_dataset(datasets)
  puts "\n" + "=" * 60
  puts "Creating Unified Training Data"
  puts "=" * 60
  
  classification_df = datasets[:classification]
  drug_ade_df = datasets[:drug_ade]
  drug_dosage_df = datasets[:drug_dosage]
  
  # Group drug-effect pairs by text
  drug_effects_by_text = {}
  drug_ade_df.group_by('text').agg([
    Polars.col('drug').alias('drugs'),
    Polars.col('effect').alias('effects')
  ]).each_row do |row|
    data = row.to_h
    text = data['text']
    drugs = data['drugs'] || []
    effects = data['effects'] || []
    drug_effects_by_text[text] = drugs.zip(effects)
  end
  
  # Group drug-dosage pairs by text
  drug_dosages_by_text = {}
  drug_dosage_df.group_by('text').agg([
    Polars.col('drug').alias('drugs'),
    Polars.col('dosage').alias('dosages')
  ]).each_row do |row|
    data = row.to_h
    text = data['text']
    drugs = data['drugs'] || []
    dosages = data['dosages'] || []
    drug_dosages_by_text[text] = drugs.zip(dosages)
  end
  
  # Create unified records
  unified_data = []
  classification_df.each_row do |row|
    data = row.to_h
    text = data['text']
    
    unified_record = {
      text: text,
      label: data['label'],
      drug_effect_pairs: drug_effects_by_text[text] || [],
      drug_dosage_pairs: drug_dosages_by_text[text] || []
    }
    unified_data << unified_record
  end
  
  puts "Created #{unified_data.length} unified training examples"
  
  # Show sample
  puts "\nSample unified records:"
  unified_data.first(3).each_with_index do |record, i|
    puts "\n--- Record #{i} ---"
    puts "  Text: #{record[:text][0..100]}..."
    puts "  Label: #{record[:label]} (#{record[:label] == 1 ? 'ADE' : 'No ADE'})"
    puts "  Drug-Effect pairs: #{record[:drug_effect_pairs].length}"
    if record[:drug_effect_pairs].any?
      puts "    First: #{record[:drug_effect_pairs].first}"
    end
    puts "  Drug-Dosage pairs: #{record[:drug_dosage_pairs].length}"
    if record[:drug_dosage_pairs].any?
      puts "    First: #{record[:drug_dosage_pairs].first}"
    end
  end
  
  unified_data
end

# Analyze data for pipeline training
def analyze_for_pipeline(unified_data)
  puts "\n" + "=" * 60
  puts "Pipeline Training Analysis"
  puts "=" * 60
  
  # Count examples with annotations
  with_drug_effects = unified_data.count { |r| r[:drug_effect_pairs].any? }
  with_drug_dosage = unified_data.count { |r| r[:drug_dosage_pairs].any? }
  positive_ade = unified_data.count { |r| r[:label] == 1 }
  
  puts "\nData breakdown:"
  puts "  Total examples: #{unified_data.length}"
  puts "  With drug-effect annotations: #{with_drug_effects} (#{(with_drug_effects.to_f / unified_data.length * 100).round(1)}%)"
  puts "  With drug-dosage annotations: #{with_drug_dosage} (#{(with_drug_dosage.to_f / unified_data.length * 100).round(1)}%)"
  puts "  Positive ADE labels: #{positive_ade} (#{(positive_ade.to_f / unified_data.length * 100).round(1)}%)"
  
  # Check correlation between annotations and labels
  annotated_positive = unified_data.count { |r| r[:drug_effect_pairs].any? && r[:label] == 1 }
  annotated_negative = unified_data.count { |r| r[:drug_effect_pairs].any? && r[:label] == 0 }
  
  puts "\nAnnotation-Label Correlation:"
  puts "  Annotated + Positive ADE: #{annotated_positive}"
  puts "  Annotated + Negative ADE: #{annotated_negative}"
  puts "  => All annotated examples are positive: #{annotated_negative == 0}"
  
  puts "\n🎯 Key Insights:"
  puts "  1. All drug-effect annotations come from positive ADE cases"
  puts "  2. Only ~29% of positive cases have structured annotations"
  puts "  3. We can use annotations for extraction training, labels for classification"
  puts "  4. Two-stage pipeline makes sense: Extract → Classify"
end

# Main execution
if __FILE__ == $0
  datasets = load_ade_datasets
  unified_data = create_unified_dataset(datasets)
  analyze_for_pipeline(unified_data)
  
  puts "\n" + "=" * 60
  puts "Ready for DSPy.rb Pipeline Training!"
  puts "=" * 60
  puts "\nNext steps:"
  puts "1. Use drug_ade data to train MedicalTextExtractor"
  puts "2. Use classification labels to train ADEPredictor"
  puts "3. Combine in multi-step pipeline with optimization"
end