# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/ade_predictor'
require_relative '../../lib/baseline_predictor'
require_relative '../../lib/ade_optimizer'

RSpec.describe "Storage & Persistence" do
  let(:storage_path) { 'tmp/dspy_storage_test' }
  
  before do
    # Clean up any existing test storage
    FileUtils.rm_rf(storage_path) if Dir.exist?(storage_path)
  end
  
  after do
    # Clean up test storage
    FileUtils.rm_rf(storage_path) if Dir.exist?(storage_path)
  end
  
  describe "DSPy built-in storage" do
    it "persists program state directly" do
      # Configure storage using DSPy's ProgramStorage directly
      program_storage = DSPy::Storage::ProgramStorage.new(
        storage_path: storage_path,
        create_directories: true
      )
      
      # Create a simple program to store
      baseline_program = DSPy::Predict.new(ADEPredictor)
      
      # Create a mock optimization result
      optimization_result = {
        optimized_program: baseline_program,
        best_score_value: 0.85,
        best_score_name: "f1_score",
        metadata: { optimizer: "test", timestamp: Time.now.iso8601 }
      }
      
      # Save the program using ProgramStorage directly
      saved_program = program_storage.save_program(
        baseline_program,
        optimization_result,
        metadata: { test: "storage_test", version: "1.0" }
      )
      
      # Verify storage worked
      expect(saved_program).not_to be_nil
      expect(saved_program.program_id).not_to be_nil
      expect(Dir.exist?(storage_path)).to be true
      expect(Dir.glob("#{storage_path}/**/*").any?).to be true
    end
    
    it "loads previously saved program state" do
      # Setup storage
      program_storage = DSPy::Storage::ProgramStorage.new(
        storage_path: storage_path,
        create_directories: true
      )
      
      # Create and save a program
      baseline_program = DSPy::Predict.new(ADEPredictor)
      optimization_result = {
        optimized_program: baseline_program,
        best_score_value: 0.92,
        best_score_name: "recall",
        metadata: { optimizer: "medical_safety", timestamp: Time.now.iso8601 }
      }
      
      saved_program = program_storage.save_program(
        baseline_program,
        optimization_result,
        metadata: { medical_focus: true, version: "2.0" }
      )
      
      # Now try to load it back
      loaded_program = program_storage.load_program(saved_program.program_id)
      
      # Verify loaded program exists and has expected structure
      expect(loaded_program).not_to be_nil
      expect(loaded_program.program).not_to be_nil
      expect(loaded_program.optimization_result).to include(:best_score_value)
      expect(loaded_program.optimization_result[:best_score_value]).to eq(0.92)
    end
    
    it "handles versioning of saved programs" do
      # Setup storage
      program_storage = DSPy::Storage::ProgramStorage.new(
        storage_path: storage_path,
        create_directories: true
      )
      
      baseline_program = DSPy::Predict.new(ADEPredictor)
      
      # Save version 1
      optimization_v1 = {
        optimized_program: baseline_program,
        best_score_value: 0.80,
        best_score_name: "f1_score",
        metadata: { optimizer: "baseline_v1", timestamp: Time.now.iso8601 }
      }
      saved_v1 = program_storage.save_program(
        baseline_program,
        optimization_v1,
        metadata: { version: "1.0", type: "baseline" }
      )
      
      # Save version 2 with different performance
      optimization_v2 = {
        optimized_program: baseline_program,
        best_score_value: 0.87,
        best_score_name: "f1_score", 
        metadata: { optimizer: "baseline_v2", timestamp: Time.now.iso8601 }
      }
      saved_v2 = program_storage.save_program(
        baseline_program,
        optimization_v2,
        metadata: { version: "2.0", type: "baseline" }
      )
      
      # Verify both versions can be loaded
      loaded_v1 = program_storage.load_program(saved_v1.program_id)
      loaded_v2 = program_storage.load_program(saved_v2.program_id)
      
      expect(loaded_v1).not_to be_nil
      expect(loaded_v2).not_to be_nil
      expect(loaded_v1.program_id).not_to eq(loaded_v2.program_id)
      expect(loaded_v1.optimization_result[:best_score_value]).to eq(0.80)
      expect(loaded_v2.optimization_result[:best_score_value]).to eq(0.87)
    end
    
    it "returns nil for missing programs" do
      program_storage = DSPy::Storage::ProgramStorage.new(
        storage_path: storage_path,
        create_directories: true
      )
      
      # Try to load nonexistent program
      loaded_program = program_storage.load_program("nonexistent_program")
      
      expect(loaded_program).to be_nil
    end
  end
  
  describe "Medical safety with persistence" do
    it "stores medical safety metadata correctly" do
      program_storage = DSPy::Storage::ProgramStorage.new(
        storage_path: storage_path,
        create_directories: true
      )
      
      # Create medical safety focused program
      baseline_program = DSPy::Predict.new(ADEPredictor)
      optimization_result = {
        optimized_program: baseline_program,
        best_score_value: 0.93,
        best_score_name: "recall", # Medical safety prioritizes recall
        metadata: { 
          optimizer: "medical_safety", 
          recall_focus: true,
          timestamp: Time.now.iso8601 
        }
      }
      
      # Save with medical safety metadata
      saved_program = program_storage.save_program(
        baseline_program,
        optimization_result,
        metadata: { 
          medical_safety: true, 
          recall_prioritized: true,
          description: "Medical safety focused ADE prediction",
          version: "safety_v1"
        }
      )
      
      # Verify program was saved with medical safety metadata
      expect(saved_program).not_to be_nil
      expect(saved_program.metadata[:medical_safety]).to be true
      expect(saved_program.metadata[:recall_prioritized]).to be true
      expect(saved_program.metadata[:description]).to include("Medical safety")
      
      # Load and verify medical safety metadata persists
      loaded_program = program_storage.load_program(saved_program.program_id)
      expect(loaded_program).not_to be_nil
      expect(loaded_program.optimization_result[:best_score_name]).to eq("recall")
      expect(loaded_program.metadata[:medical_safety]).to be true
    end
  end
end