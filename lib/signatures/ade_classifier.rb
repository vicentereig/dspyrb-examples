# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

# Signature for binary classification of adverse drug events
# Trained on 23,516 classification labels from ADE dataset
class ADEClassifier < DSPy::Signature
  description "Classify whether extracted drugs and effects indicate an adverse drug event"

  input do
    const :text, String, description: "Original medical text"
    const :drugs, T::Array[String], description: "Extracted drug names"
    const :effects, T::Array[String], description: "Extracted adverse effects"
  end

  output do
    const :has_ade, T::Boolean, description: "True if adverse drug event is present, false otherwise"
    const :confidence, Float, description: "Confidence score between 0.0 and 1.0"
  end
end