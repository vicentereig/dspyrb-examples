# frozen_string_literal: true

require 'polars-df'
require 'dspy'
require_relative '../signatures/drug_extractor'
require_relative '../signatures/effect_extractor'
require_relative '../signatures/ade_classifier'

# Dataset loader for ADE Corpus V2 using Polars
# Loads all three configurations and creates unified training data
class AdeDatasetLoader
  attr_reader :data_dir

  def initialize(data_dir: 'data/ade_corpus_v2')
    @data_dir = data_dir
    @classification_df = nil
    @drug_ade_df = nil
    @drug_dosage_df = nil
    @unified_data = nil
  end

  # Load all three parquet files
  def load_datasets
    @classification_df = Polars.read_parquet("#{@data_dir}/Ade_corpus_v2_classification/train-00000-of-00001.parquet")
    @drug_ade_df = Polars.read_parquet("#{@data_dir}/Ade_corpus_v2_drug_ade_relation/train-00000-of-00001.parquet")
    @drug_dosage_df = Polars.read_parquet("#{@data_dir}/Ade_corpus_v2_drug_dosage_relation/train-00000-of-00001.parquet")

    puts "📊 Loaded datasets:"
    puts "  Classification: #{@classification_df.shape}"
    puts "  Drug-ADE: #{@drug_ade_df.shape}"
    puts "  Drug-Dosage: #{@drug_dosage_df.shape}"

    self
  end

  # Create unified dataset combining all three configurations
  def create_unified_dataset
    raise "Datasets not loaded. Call load_datasets first." unless @classification_df

    # Group drug-effect pairs by text
    drug_effects_by_text = {}
    @drug_ade_df.group_by('text').agg([
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
    @drug_dosage_df.group_by('text').agg([
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
    @unified_data = []
    @classification_df.each_row do |row|
      data = row.to_h
      text = data['text']

      unified_record = {
        text: text,
        label: data['label'] == 1,  # Convert to boolean
        drug_effect_pairs: drug_effects_by_text[text] || [],
        drug_dosage_pairs: drug_dosages_by_text[text] || []
      }
      @unified_data << unified_record
    end

    puts "✅ Created #{@unified_data.length} unified examples"
    
    # Stats
    with_drug_effects = @unified_data.count { |r| r[:drug_effect_pairs].any? }
    with_drug_dosage = @unified_data.count { |r| r[:drug_dosage_pairs].any? }
    positive_ade = @unified_data.count { |r| r[:label] }
    
    puts "  With drug-effect annotations: #{with_drug_effects}"
    puts "  With drug-dosage annotations: #{with_drug_dosage}"
    puts "  Positive ADE labels: #{positive_ade}"

    self
  end

  # Split dataset into train/validation/test
  def split_dataset(train_ratio: 0.7, val_ratio: 0.15, test_ratio: 0.15)
    raise "Unified data not created. Call create_unified_dataset first." unless @unified_data

    # Ensure ratios sum to 1
    total_ratio = train_ratio + val_ratio + test_ratio
    unless (total_ratio - 1.0).abs < 0.001
      raise "Ratios must sum to 1.0, got #{total_ratio}"
    end

    # Stratified split based on label
    positive_examples = @unified_data.select { |r| r[:label] }
    negative_examples = @unified_data.select { |r| !r[:label] }

    puts "📊 Stratified split:"
    puts "  Positive examples: #{positive_examples.size}"
    puts "  Negative examples: #{negative_examples.size}"

    # Split positive examples
    pos_train_size = (positive_examples.size * train_ratio).round
    pos_val_size = (positive_examples.size * val_ratio).round
    
    pos_shuffled = positive_examples.shuffle
    pos_train = pos_shuffled[0...pos_train_size]
    pos_val = pos_shuffled[pos_train_size...(pos_train_size + pos_val_size)]
    pos_test = pos_shuffled[(pos_train_size + pos_val_size)..-1]

    # Split negative examples
    neg_train_size = (negative_examples.size * train_ratio).round
    neg_val_size = (negative_examples.size * val_ratio).round
    
    neg_shuffled = negative_examples.shuffle
    neg_train = neg_shuffled[0...neg_train_size]
    neg_val = neg_shuffled[neg_train_size...(neg_train_size + neg_val_size)]
    neg_test = neg_shuffled[(neg_train_size + neg_val_size)..-1]

    # Combine and shuffle
    train = (pos_train + neg_train).shuffle
    val = (pos_val + neg_val).shuffle
    test = (pos_test + neg_test).shuffle

    puts "✅ Split completed:"
    puts "  Train: #{train.size} (#{train.count { |r| r[:label] }} positive)"
    puts "  Val: #{val.size} (#{val.count { |r| r[:label] }} positive)"
    puts "  Test: #{test.size} (#{test.count { |r| r[:label] }} positive)"

    { train: train, val: val, test: test }
  end

  # Convert unified records to DSPy examples for training different components
  def create_extraction_examples
    raise "Unified data not created. Call create_unified_dataset first." unless @unified_data

    drug_examples = []
    effect_examples = []

    @unified_data.each do |record|
      text = record[:text]
      
      # Create drug extraction examples
      unless record[:drug_effect_pairs].empty?
        drugs = record[:drug_effect_pairs].map(&:first).uniq
        drug_examples << DSPy::Example.new(
          signature_class: DrugExtractor,
          input: { text: text },
          expected: { drugs: drugs }
        )
      end

      # Add drug-dosage pairs if available
      unless record[:drug_dosage_pairs].empty?
        dosage_drugs = record[:drug_dosage_pairs].map(&:first).uniq
        # Don't duplicate if already added from drug_effect_pairs
        unless record[:drug_effect_pairs].any?
          drug_examples << DSPy::Example.new(
            signature_class: DrugExtractor,
            input: { text: text },
            expected: { drugs: dosage_drugs }
          )
        end
      end

      # Create effect extraction examples
      unless record[:drug_effect_pairs].empty?
        effects = record[:drug_effect_pairs].map(&:last).uniq
        effect_examples << DSPy::Example.new(
          signature_class: EffectExtractor,
          input: { text: text },
          expected: { effects: effects }
        )
      end
    end

    puts "📝 Created extraction examples:"
    puts "  Drug extraction: #{drug_examples.size} examples"
    puts "  Effect extraction: #{effect_examples.size} examples"

    { drug_extraction: drug_examples, effect_extraction: effect_examples }
  end

  # Convert unified records to DSPy examples for classification
  def create_classification_examples(split_data)
    classification_examples = {}
    
    %i[train val test].each do |split|
      examples = split_data[split].map do |record|
        DSPy::Example.new(
          signature_class: ADEClassifier,
          input: {
            text: record[:text],
            drugs: record[:drug_effect_pairs].map(&:first),
            effects: record[:drug_effect_pairs].map(&:last)
          },
          expected: {
            has_ade: record[:label],
            confidence: record[:label] ? 0.8 : 0.2  # Default confidence
          }
        )
      end
      
      classification_examples[split] = examples
    end

    puts "📊 Created classification examples:"
    puts "  Train: #{classification_examples[:train].size}"
    puts "  Val: #{classification_examples[:val].size}"
    puts "  Test: #{classification_examples[:test].size}"

    classification_examples
  end

  # Convenience method to get everything ready for training
  def prepare_training_data
    load_datasets
    create_unified_dataset
    split_data = split_dataset
    
    {
      extraction_examples: create_extraction_examples,
      classification_examples: create_classification_examples(split_data),
      raw_split: split_data
    }
  end
end