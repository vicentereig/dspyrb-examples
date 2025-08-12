# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

# Signature for extracting adverse effects from medical text
# Trained on 6,821 effect annotations from ADE dataset
class EffectExtractor < DSPy::Signature
  description "Extract adverse drug effects mentioned in medical text"

  input do
    const :text, String, description: "Medical text containing adverse effects"
  end

  output do
    const :effects, T::Array[String], description: "List of adverse effects found in the text"
  end
end