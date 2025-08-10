# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

class ADEPredictor < DSPy::Signature
  description "Predict if a patient report contains an adverse drug event"
  
  class ADEStatus < T::Enum
    enums do
      NoADE = new('no_adverse_event')
      MildADE = new('mild_adverse_event')
      SevereADE = new('severe_adverse_event')
    end
  end
end