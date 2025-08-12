# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

# Signature for extracting drug names from medical text
# Trained on 6,821 drug annotations from ADE dataset
class DrugExtractor < DSPy::Signature
  description "Extract drug names mentioned in medical text"

  input do
    const :text, String, description: "Medical text containing drug mentions"
  end

  output do
    const :drugs, T::Array[String], description: "List of drug names found in the text"
  end
end