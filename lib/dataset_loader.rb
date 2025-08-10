# frozen_string_literal: true

require 'net/http'
require 'json'
require 'fileutils'
require 'uri'
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
    
    # For now, return empty array - will implement parquet reading later
    []
  end
  
  def transform_to_examples(raw_data)
    return [] if raw_data.nil? || raw_data.empty?
    
    raw_data.map do |item|
      next nil unless valid_data_item?(item)
      
      # Extract medications and symptoms from text
      text = item['text'] || ''
      medications = extract_medications(text, item['drug'])
      symptoms = extract_symptoms(text, item['effect'])
      
      # Map label to ADEStatus
      ade_status = map_label_to_status(item['label'])
      
      # Create DSPy::Example
      DSPy::Example.new(
        signature_class: ADEPredictor,
        input: {
          patient_report: text,
          medications: medications,
          symptoms: symptoms
        },
        expected: {
          ade_status: ade_status,
          confidence: 1.0,  # Ground truth has full confidence
          drug_symptom_pairs: create_drug_symptom_pairs(medications, symptoms)
        }
      )
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
  
  def download_file(url, local_path = nil)
    uri = URI(url)
    local_path ||= File.join(@data_dir, File.basename(uri.path))
    
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        File.open(local_path, 'wb') do |file|
          response.read_body do |chunk|
            file.write(chunk)
          end
        end
      end
    end
    
    puts "Downloaded: #{local_path}"
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