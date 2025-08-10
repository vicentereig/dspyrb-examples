# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/dataset_loader'

RSpec.describe DatasetLoader do
  let(:loader) { DatasetLoader.new }
  
  describe '#fetch_dataset_info' do
    it 'retrieves parquet URLs from HuggingFace API', vcr: { cassette_name: 'dataset_loader/huggingface_api' } do
      info = loader.fetch_dataset_info
      
      expect(info).to be_a(Hash)
      expect(info).to have_key(:parquet_files)
      expect(info[:parquet_files]).to be_an(Array)
      expect(info[:parquet_files].first).to have_key(:url)
    end
    
    it 'handles API errors gracefully' do
      allow(loader).to receive(:fetch_from_api).and_raise(StandardError.new("API Error"))
      
      expect { loader.fetch_dataset_info }.not_to raise_error
      expect(loader.fetch_dataset_info).to be_nil
    end
    
    it 'caches API responses' do
      # Mock the API call first time
      allow(loader).to receive(:fetch_from_api).and_return({
        parquet_files: [{ url: 'http://example.com/test.parquet' }]
      })
      
      # First call should hit API
      first_info = loader.fetch_dataset_info
      
      # Second call should use cache (no additional API call)
      cached_info = loader.fetch_dataset_info
      
      expect(cached_info).to eq(first_info)
      expect(loader).to have_received(:fetch_from_api).once
    end
  end
  
  describe '#download_dataset' do
    let(:mock_parquet_url) { 'https://example.com/data.parquet' }
    
    it 'downloads parquet files to local cache' do
      allow(loader).to receive(:fetch_dataset_info).and_return({
        parquet_files: [{ url: mock_parquet_url }]
      })
      
      expect(loader).to receive(:download_file).with(mock_parquet_url, "./data/data.parquet")
      loader.download_dataset
    end
    
    it 'skips already downloaded files' do
      allow(loader).to receive(:file_exists?).and_return(true)
      
      expect(loader).not_to receive(:download_file)
      loader.download_dataset
    end
    
    it 'creates data directory if not exists' do
      expect(FileUtils).to receive(:mkdir_p).with(loader.data_dir)
      loader.download_dataset
    end
  end
  
  describe '#load_examples' do
    it 'loads and parses dataset files' do
      # For now, we expect empty array since parquet parsing is not implemented
      examples = loader.load_examples
      
      expect(examples).to be_an(Array)
      # Will be empty until we implement parquet parsing
      expect(examples).to be_empty
    end
    
    it 'returns empty array if no data files exist' do
      allow(loader).to receive(:data_files_exist?).and_return(false)
      
      expect(loader.load_examples).to eq([])
    end
  end
  
  describe '#transform_to_examples' do
    let(:raw_data) do
      [{
        'text' => 'Patient experienced severe headache after taking aspirin',
        'label' => 1,
        'drug' => 'aspirin',
        'effect' => 'headache'
      }]
    end
    
    it 'converts raw data to DSPy::Example format' do
      examples = loader.transform_to_examples(raw_data)
      
      expect(examples).to be_an(Array)
      expect(examples.first).to be_a(DSPy::Example)
    end
    
    it 'extracts medications from text' do
      examples = loader.transform_to_examples(raw_data)
      example = examples.first
      
      expect(example.input_values[:medications]).to include('aspirin')
    end
    
    it 'extracts symptoms from text' do
      examples = loader.transform_to_examples(raw_data)
      example = examples.first
      
      expect(example.input_values[:symptoms]).to include('headache')
    end
    
    it 'maps binary labels to ADEStatus enum' do
      examples = loader.transform_to_examples(raw_data)
      example = examples.first
      
      expect(example.expected_values[:ade_status]).to be_a(ADEPredictor::ADEStatus)
    end
    
    it 'handles malformed data gracefully' do
      bad_data = [{ 'invalid' => 'data' }]
      
      expect { loader.transform_to_examples(bad_data) }.not_to raise_error
      expect(loader.transform_to_examples(bad_data)).to eq([])
    end
  end
  
  describe '#split_dataset' do
    let(:examples) { Array.new(100) { |i| double("Example#{i}") } }
    
    it 'splits data into train/val/test sets' do
      train, val, test = loader.split_dataset(examples)
      
      expect(train.size).to eq(70)  # 70% train
      expect(val.size).to eq(15)    # 15% validation
      expect(test.size).to eq(15)   # 15% test
    end
    
    it 'maintains class balance in splits' do
      # Create examples with labels
      positive_examples = Array.new(50) { double("Positive", ade_present: true) }
      negative_examples = Array.new(50) { double("Negative", ade_present: false) }
      all_examples = positive_examples + negative_examples
      
      train, val, test = loader.split_dataset(all_examples, stratify: true)
      
      # Check balance in each split
      train_positive = train.count { |e| e.ade_present }
      expect(train_positive).to be_between(30, 40)  # ~35 expected
    end
    
    it 'ensures no data leakage between sets' do
      train, val, test = loader.split_dataset(examples)
      
      # No overlap between sets
      expect(train & val).to be_empty
      expect(train & test).to be_empty
      expect(val & test).to be_empty
      
      # All examples accounted for
      expect(train + val + test).to match_array(examples)
    end
    
    it 'accepts custom split ratios' do
      train, val, test = loader.split_dataset(examples, ratios: [0.8, 0.1, 0.1])
      
      expect(train.size).to eq(80)
      expect(val.size).to eq(10)
      expect(test.size).to eq(10)
    end
  end
end