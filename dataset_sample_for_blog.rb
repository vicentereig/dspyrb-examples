#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate sample dataset examples for blog post documentation

require_relative 'lib/dataset_loader'
require_relative 'lib/ade_predictor'

puts "📊 Dataset Sample for Blog Post Documentation"
puts "=" * 50

# Create sample of synthetic ADE data that would be used in practice
def generate_realistic_ade_examples
  [
    {
      sentence: "Patient experienced mild nausea and dizziness after taking ibuprofen for headache relief. Symptoms resolved within 2 hours.",
      ade_present: true,
      severity: "mild",
      drug: "ibuprofen", 
      symptom: "nausea, dizziness"
    },
    {
      sentence: "Patient has been taking lisinopril for 6 months with excellent blood pressure control. No adverse effects reported.",
      ade_present: false,
      severity: "none",
      drug: "lisinopril",
      symptom: "none"
    },
    {
      sentence: "Severe allergic reaction developed within 30 minutes of penicillin injection. Patient experienced difficulty breathing, hives, and required emergency treatment.",
      ade_present: true,
      severity: "severe", 
      drug: "penicillin",
      symptom: "difficulty breathing, hives"
    },
    {
      sentence: "Patient reports mild stomach upset after starting metformin but continues treatment as symptoms are manageable.",
      ade_present: true,
      severity: "mild",
      drug: "metformin",
      symptom: "stomach upset"
    },
    {
      sentence: "No side effects observed with current dose of atorvastatin. Patient cholesterol levels improving steadily.",
      ade_present: false,
      severity: "none",
      drug: "atorvastatin", 
      symptom: "none"
    },
    {
      sentence: "Patient developed serious rash and joint pain after 3 days on sulfamethoxazole. Medication discontinued immediately.",
      ade_present: true,
      severity: "severe",
      drug: "sulfamethoxazole",
      symptom: "rash, joint pain"
    }
  ]
end

def transform_to_dspy_examples(raw_examples)
  raw_examples.map do |item|
    # Extract medications mentioned in text
    medications = [item[:drug]].compact
    
    # Map severity to ADE status
    ade_status = case item[:severity]
    when "none"
      ADEPredictor::ADEStatus::NoADE
    when "mild" 
      ADEPredictor::ADEStatus::MildADE
    when "severe"
      ADEPredictor::ADEStatus::SevereADE
    else
      ADEPredictor::ADEStatus::NoADE
    end
    
    # Create confidence score based on clarity of the case
    confidence = case item[:severity]
    when "none" then 0.9
    when "mild" then 0.75
    when "severe" then 0.95
    else 0.5
    end
    
    # Create drug-symptom pairs if ADE present
    drug_symptom_pairs = if item[:ade_present] && item[:drug] && item[:symptom] != "none"
      [{
        _type: "DrugSymptomPair",
        drug: item[:drug],
        symptom: item[:symptom]
      }]
    else
      []
    end
    
    {
      input: {
        patient_report: item[:sentence],
        medications: medications,
        symptoms: item[:symptom] == "none" ? "" : item[:symptom]
      },
      expected: {
        ade_status: ade_status,
        confidence: confidence,
        drug_symptom_pairs: drug_symptom_pairs
      },
      raw_data: item
    }
  end
end

# 1. Original Dataset Sample
puts "\n📋 1. Original Dataset Examples (Raw Format)"
puts "-" * 45

raw_examples = generate_realistic_ade_examples
puts "Sample of #{raw_examples.size} examples from synthetic ADE dataset:\n\n"

raw_examples.each_with_index do |example, i|
  puts "Example #{i+1}:"
  puts "  Text: \"#{example[:sentence]}\""
  puts "  ADE Present: #{example[:ade_present]}"
  puts "  Severity: #{example[:severity]}"
  puts "  Drug: #{example[:drug]}"
  puts "  Symptom: #{example[:symptom]}"
  puts ""
end

# 2. Transformed Training Examples
puts "🔧 2. DSPy Training Examples (Transformed Format)"
puts "-" * 48

dspy_examples = transform_to_dspy_examples(raw_examples)
puts "Training examples ready for DSPy optimization:\n\n"

dspy_examples.each_with_index do |example, i|
  puts "Training Example #{i+1}:"
  puts "  Input:"
  puts "    patient_report: \"#{example[:input][:patient_report]}\""
  puts "    medications: #{example[:input][:medications]}"
  puts "    symptoms: \"#{example[:input][:symptoms]}\""
  puts "  Expected Output:"
  puts "    ade_status: #{example[:expected][:ade_status]}"
  puts "    confidence: #{example[:expected][:confidence]}"
  puts "    drug_symptom_pairs: #{example[:expected][:drug_symptom_pairs]}"
  puts ""
end

# 3. Dataset Statistics
puts "📊 3. Dataset Statistics"
puts "-" * 25

total_examples = raw_examples.size
ade_present = raw_examples.count { |e| e[:ade_present] }
no_ade = total_examples - ade_present

severity_counts = raw_examples.group_by { |e| e[:severity] }.transform_values(&:count)

puts "Dataset Composition:"
puts "  Total Examples: #{total_examples}"
puts "  ADE Present: #{ade_present} (#{(ade_present.to_f/total_examples*100).round(1)}%)"
puts "  No ADE: #{no_ade} (#{(no_ade.to_f/total_examples*100).round(1)}%)"
puts ""
puts "Severity Distribution:"
severity_counts.each do |severity, count|
  puts "  #{severity.capitalize}: #{count} (#{(count.to_f/total_examples*100).round(1)}%)"
end

# 4. Training/Validation Split Example
puts "\n🎯 4. Training/Validation Split Example"
puts "-" * 35

# Simulate what the actual split would look like
train_size = (raw_examples.size * 0.7).round
val_size = (raw_examples.size * 0.15).round
test_size = raw_examples.size - train_size - val_size

puts "Data Split Strategy:"
puts "  Training: #{train_size} examples (70%)"
puts "  Validation: #{val_size} examples (15%)"
puts "  Test: #{test_size} examples (15%)"
puts ""

puts "Training Examples (#{train_size} examples):"
dspy_examples.first(train_size).each_with_index do |example, i|
  puts "  #{i+1}. \"#{example[:input][:patient_report][0..60]}...\" → #{example[:expected][:ade_status]}"
end

puts "\nValidation Examples (#{val_size} examples):"
dspy_examples.drop(train_size).first(val_size).each_with_index do |example, i|
  puts "  #{i+1}. \"#{example[:input][:patient_report][0..60]}...\" → #{example[:expected][:ade_status]}"
end

# 5. Medical Context and Challenges
puts "\n🏥 5. Medical Context & Challenges"
puts "-" * 32

puts "Key Challenges in ADE Detection:"
puts "• Severity Classification: Distinguishing mild vs severe ADEs"
puts "• Drug-Symptom Association: Linking symptoms to specific medications"
puts "• Temporal Relationships: Understanding timing of medication and symptoms"
puts "• Medical Safety: Minimizing false negatives (missed ADEs)"
puts "• Context Understanding: Differentiating ADEs from underlying conditions"
puts ""

puts "Why This Matters:"
puts "• False Negatives: Missed ADEs can lead to continued harmful exposure"
puts "• False Positives: Can lead to unnecessary treatment discontinuation"
puts "• Recall Priority: Better to flag potential ADE for review than miss it"
puts "• Clinical Decision Support: Assists healthcare providers in ADE monitoring"

# 6. Export for Blog Post
puts "\n💾 6. Exporting Sample for Blog Post"
puts "-" * 33

blog_sample = {
  original_format: raw_examples.first(3),
  dspy_format: dspy_examples.first(3),
  statistics: {
    total_examples: total_examples,
    ade_present: ade_present,
    no_ade: no_ade,
    severity_distribution: severity_counts
  },
  data_split: {
    training: train_size,
    validation: val_size, 
    test: test_size
  },
  medical_context: {
    challenges: [
      "Severity classification (mild vs severe)",
      "Drug-symptom association", 
      "Temporal relationships",
      "Medical safety (minimize false negatives)",
      "Context understanding"
    ],
    clinical_importance: "Assists healthcare providers in adverse drug event monitoring while prioritizing patient safety"
  }
}

require 'json'
File.write('dataset_sample_for_blog.json', JSON.pretty_generate(blog_sample))

puts "✅ Dataset sample exported to dataset_sample_for_blog.json"
puts "   Ready for blog post documentation!"

# 7. GitHub Issue Update Format
puts "\n📝 7. GitHub Issue Update Format"
puts "-" * 30

puts "\n```markdown"
puts "## Dataset Sample Examples"
puts ""
puts "### Original Raw Data Format"
puts "Here are examples of the synthetic ADE data used for training:"
puts ""
puts "| Patient Report | ADE Present | Severity | Drug | Symptoms |"
puts "|---------------|-------------|----------|------|----------|"
raw_examples.first(3).each do |ex|
  puts "| #{ex[:sentence][0..50]}... | #{ex[:ade_present]} | #{ex[:severity]} | #{ex[:drug]} | #{ex[:symptom]} |"
end
puts ""
puts "### DSPy Training Format"
puts "After transformation for DSPy optimization:"
puts ""
dspy_examples.first(2).each_with_index do |ex, i|
  puts "**Example #{i+1}:**"
  puts "```json"
  puts JSON.pretty_generate({
    input: ex[:input],
    expected: ex[:expected]
  })
  puts "```"
  puts ""
end
puts ""
puts "### Dataset Statistics"
puts "- Total Examples: #{total_examples}"
puts "- ADE Present: #{ade_present} (#{(ade_present.to_f/total_examples*100).round(1)}%)"
puts "- No ADE: #{no_ade} (#{(no_ade.to_f/total_examples*100).round(1)}%)"
puts "- Training/Validation/Test: #{train_size}/#{val_size}/#{test_size} (70%/15%/15%)"
puts "```"

puts "\n🎯 Ready to copy-paste the markdown section above to the GitHub issue!"