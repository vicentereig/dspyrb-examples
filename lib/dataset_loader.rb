# frozen_string_literal: true

require 'net/http'
require 'json'
require 'fileutils'
require 'uri'
require 'parquet'
require_relative 'ade_predictor'
require 'dspy'

class DatasetLoader
  attr_reader :data_dir
  
  HUGGINGFACE_API_URL = 'https://datasets-server.huggingface.co/parquet'
  DATASET_NAME = 'ade-benchmark-corpus/ade_corpus_v2'
  
  def initialize(data_dir: './data')
    @data_dir = data_dir
    @cache = {}
  end
  
  def fetch_dataset_info
    return @cache[:dataset_info] if @cache[:dataset_info]
    
    begin
      @cache[:dataset_info] = fetch_from_api
    rescue StandardError => e
      puts "Error fetching dataset info: #{e.message}"
      nil
    end
  end
  
  def download_dataset
    FileUtils.mkdir_p(@data_dir)
    
    info = fetch_dataset_info
    return unless info
    
    info[:parquet_files].each do |file|
      local_path = File.join(@data_dir, File.basename(file[:url]))
      next if file_exists?(local_path)
      
      download_file(file[:url], local_path)
    end
  end
  
  def load_examples
    return [] unless data_files_exist?
    
    all_examples = []
    
    # Load all parquet files in the data directory
    Dir.glob(File.join(@data_dir, '*.parquet')).each do |parquet_file|
      puts "Loading parquet file: #{parquet_file}"
      examples = load_parquet_file(parquet_file)
      all_examples.concat(examples) if examples
    end
    
    puts "Loaded #{all_examples.size} examples from parquet files"
    all_examples
  end
  
  def load_parquet_file(parquet_file)
    examples = []
    
    begin
      # Use red-parquet to read the file
      table = Arrow::Table.load(parquet_file)
      
      # Convert to Ruby array of hashes
      table.each_record_batch do |batch|
        batch.each do |record|
          # Try to extract the fields based on common ADE dataset structures
          examples << {
            'text' => record['text'] || record['sentence'] || record['content'],
            'label' => (record['label'] || record['ade_label'] || 0).to_i,
            'drug' => record['drug'] || record['medication'] || extract_medications(record['text'] || '').first,
            'effect' => record['effect'] || record['symptom'] || record['adverse_effect']
          }
        end
      end
    rescue StandardError => e
      puts "Error loading parquet file #{parquet_file}: #{e.message}"
      return []
    end
    
    examples
  end
  
  def transform_to_examples(raw_data)
    return [] if raw_data.nil? || raw_data.empty?
    
    # Load the extractor signature for creating examples
    require_relative 'medical_text_extractor'
    
    raw_data.map do |item|
      next nil unless valid_data_item?(item)
      
      # Get the raw text
      text = item['text'] || ''
      
      # Map label to ADEStatus (for expected output)
      ade_status = map_label_to_status(item['label'])
      
      # For the pipeline, we'll just provide the raw text as input
      # The extraction will happen in the pipeline
      # Create a minimal example structure
      {
        input: {
          text: text  # Just raw text - extraction happens in pipeline
        },
        expected: {
          ade_status: ade_status,
          confidence: 1.0,  # Ground truth has full confidence
          drug_symptom_pairs: []  # Will be extracted by pipeline
        }
      }
    rescue StandardError => e
      puts "Error transforming item: #{e.message}"
      nil
    end.compact
  end
  
  def split_dataset(examples, ratios: [0.7, 0.15, 0.15], stratify: false)
    return [[], [], []] if examples.empty?
    
    train_ratio, val_ratio, test_ratio = ratios
    total = examples.size
    
    train_size = (total * train_ratio).round
    val_size = (total * val_ratio).round
    test_size = total - train_size - val_size
    
    if stratify
      # Group by ADE presence for stratified split
      positive = examples.select { |e| e.respond_to?(:ade_present) && e.ade_present }
      negative = examples.reject { |e| e.respond_to?(:ade_present) && e.ade_present }
      
      # Split each group proportionally
      train = positive.first((positive.size * train_ratio).round) + 
              negative.first((negative.size * train_ratio).round)
      
      remaining_pos = positive.drop((positive.size * train_ratio).round)
      remaining_neg = negative.drop((negative.size * train_ratio).round)
      
      val = remaining_pos.first((positive.size * val_ratio).round) +
            remaining_neg.first((negative.size * val_ratio).round)
      
      test = remaining_pos.drop((positive.size * val_ratio).round) +
             remaining_neg.drop((negative.size * val_ratio).round)
      
      [train.shuffle, val.shuffle, test.shuffle]
    else
      # Simple random split
      shuffled = examples.shuffle
      train = shuffled.first(train_size)
      val = shuffled[train_size, val_size]
      test = shuffled.last(test_size)
      
      [train, val, test]
    end
  end
  
  def file_exists?(path)
    File.exist?(path)
  end
  
  def data_files_exist?
    Dir.exist?(@data_dir) && !Dir.glob(File.join(@data_dir, '*.parquet')).empty?
  end
  
  # Helper method for creating synthetic examples for integration testing
  def synthetic_examples_to_dspy(synthetic_examples)
    synthetic_examples.map do |example|
      # Extract medications and symptoms from sentence
      medications = extract_medications(example[:sentence])
      symptoms = extract_symptoms(example[:sentence])
      
      # Map to ADE status
      ade_status = map_label_to_status(example[:label])
      
      # Create drug-symptom pairs
      drug_symptom_pairs = create_drug_symptom_pairs(medications, symptoms)
      
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: example[:sentence],
          medications: medications,
          symptoms: symptoms
        },
        expected: {
          ade_status: ade_status,
          confidence: example[:label] == 1 ? 0.8 : 0.9, # Higher confidence for no ADE
          drug_symptom_pairs: drug_symptom_pairs
        }
      )
    end
  end
  
  private
  
  def fetch_from_api
    uri = URI("#{HUGGINGFACE_API_URL}?dataset=#{DATASET_NAME}")
    response = Net::HTTP.get_response(uri)
    
    raise "API request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    
    data = JSON.parse(response.body)
    {
      parquet_files: data['parquet_files'].map { |f| { url: f['url'] } }
    }
  end
  
  def download_file(url, local_path = nil, max_redirects = 5)
    uri = URI(url)
    local_path ||= File.join(@data_dir, File.basename(uri.path))
    redirects = 0
    
    while redirects < max_redirects
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        
        case response
        when Net::HTTPRedirection
          # Follow redirect
          redirects += 1
          new_url = response['location']
          puts "Following redirect to: #{new_url}" if redirects == 1
          uri = URI(new_url)
        when Net::HTTPSuccess
          # Save the file
          File.open(local_path, 'wb') do |file|
            file.write(response.body)
          end
          puts "Downloaded: #{local_path}"
          return
        else
          raise "Download failed: #{response.code} #{response.message}"
        end
      end
    end
    
    raise "Too many redirects while downloading #{url}"
  end
  
  def valid_data_item?(item)
    item.is_a?(Hash) && item.key?('text') && item.key?('label')
  end
  
  def extract_medications(text, drug_field = nil)
    medications = []
    medications << drug_field if drug_field
    
    # Simple extraction - look for common medication patterns
    # In production, would use NER or more sophisticated extraction
    med_patterns = /\b(aspirin|ibuprofen|penicillin|acetaminophen|warfarin)\b/i
    text.scan(med_patterns).flatten.uniq.each do |med|
      medications << med.downcase unless medications.include?(med.downcase)
    end
    
    medications
  end
  
  def extract_symptoms(text, effect_field = nil)
    symptoms = []
    symptoms << effect_field if effect_field
    
    # Simple extraction for common symptoms
    symptom_patterns = /\b(headache|nausea|dizziness|rash|vomiting|fatigue|fever)\b/i
    found = text.scan(symptom_patterns).flatten.uniq
    
    (symptoms + found.map(&:downcase)).join(', ')
  end
  
  def map_label_to_status(label)
    case label
    when 0
      ADEPredictor::ADEStatus::NoADE
    when 1
      ADEPredictor::ADEStatus::MildADE  # Default to mild for binary classification
    else
      ADEPredictor::ADEStatus::NoADE
    end
  end
  
  def create_drug_symptom_pairs(medications, symptoms)
    return [] if medications.empty? || symptoms.empty?
    
    # For simplicity, pair each drug with first symptom
    # In production, would use more sophisticated pairing logic
    symptom_list = symptoms.split(',').map(&:strip)
    
    medications.map do |drug|
      ADEPredictor::DrugSymptomPair.new(
        drug: drug,
        symptom: symptom_list.first || ''
      )
    end
  end
end