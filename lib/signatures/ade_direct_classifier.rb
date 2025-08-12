# frozen_string_literal: true

require 'dspy'

# Direct end-to-end ADE classification signature
# Takes medical text and directly predicts ADE presence without intermediate extraction
class ADEDirectClassifier < DSPy::Signature
  description "Directly classify if medical text describes an adverse drug event (ADE)"
  
  input do
    const :text, String, description: "Medical text that may describe adverse drug events"
  end

  output do
    const :has_ade, T::Boolean, description: "True if the text describes an adverse drug event"
    const :confidence, Float, description: "Confidence score between 0.0 and 1.0"
    const :reasoning, String, description: "Brief explanation of the classification decision"
  end
end