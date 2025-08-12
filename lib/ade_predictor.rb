# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

class ADEPredictor < DSPy::Signature
  description "Predict if a patient report contains an adverse drug event"

  class ADEStatus < T::Enum
    enums do
      NoADE = new('0')  # No adverse drug event
      ADE = new('1')    # Adverse drug event detected
    end
  end

  class DrugSymptomPair < T::Struct
    const :drug, String
    const :symptom, String
  end

  input do
    const :patient_report, String, description: "The patient's medical report text"
    const :medications, T::Array[String], description: "List of medications mentioned"
    const :symptoms, T::Array[String], description: "Symptoms described by the patient"
  end

  output do
    const :ade_status, ADEStatus, description: "Severity level of adverse drug event"
    const :confidence, Float, description: "Confidence score between 0 and 1"
    const :drug_symptom_pairs, T.any(T::Array[DrugSymptomPair], T::Array[T::Hash[T.any(String, Symbol), T.untyped]]), description: "Pairs of drugs and related symptoms"
  end
end
