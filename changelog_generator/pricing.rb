# frozen_string_literal: true

# Pricing information for different models
# Prices are in USD per 1M tokens
# Updated: January 2025
module Pricing
  MODELS = {
    # Anthropic models - Claude 4 (latest)
    'anthropic/claude-opus-4-20250514' => {
      input: 15.00,   # $15 per 1M input tokens
      output: 75.00   # $75 per 1M output tokens
    },
    'anthropic/claude-sonnet-4-20250514' => {
      input: 3.00,    # $3 per 1M input tokens
      output: 15.00   # $15 per 1M output tokens
    },
    
    # Anthropic models - Claude 3.5
    'anthropic/claude-3-5-sonnet-20241022' => {
      input: 3.00,    # $3 per 1M input tokens
      output: 15.00   # $15 per 1M output tokens
    },
    
    # Anthropic models - Claude 3
    'anthropic/claude-3-opus-20240229' => {
      input: 15.00,   # $15 per 1M input tokens
      output: 75.00   # $75 per 1M output tokens
    },
    'anthropic/claude-3-sonnet-20240229' => {
      input: 3.00,    # $3 per 1M input tokens
      output: 15.00   # $15 per 1M output tokens
    },
    'anthropic/claude-3-haiku-20240307' => {
      input: 0.25,    # $0.25 per 1M input tokens
      output: 1.25    # $1.25 per 1M output tokens
    },
    
    # OpenAI models
    'openai/gpt-4o' => {
      input: 5.00,    # $5 per 1M input tokens
      output: 15.00   # $15 per 1M output tokens
    },
    'openai/gpt-4o-mini' => {
      input: 0.15,    # $0.15 per 1M input tokens
      output: 0.60    # $0.60 per 1M output tokens
    },
    'openai/gpt-4-turbo' => {
      input: 10.00,   # $10 per 1M input tokens
      output: 30.00   # $30 per 1M output tokens
    },
    'openai/gpt-3.5-turbo' => {
      input: 0.50,    # $0.50 per 1M input tokens
      output: 1.50    # $1.50 per 1M output tokens
    }
  }.freeze

  class << self
    def calculate_cost(model:, input_tokens:, output_tokens:)
      pricing = MODELS[model]
      raise "Unknown model: #{model}" unless pricing

      # Calculate costs (prices are per 1M tokens)
      input_cost = (input_tokens / 1_000_000.0) * pricing[:input]
      output_cost = (output_tokens / 1_000_000.0) * pricing[:output]
      total_cost = input_cost + output_cost

      {
        input_cost: input_cost,
        output_cost: output_cost,
        total: total_cost,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: input_tokens + output_tokens
      }
    end

    def format_cost(cost)
      "$#{sprintf('%.4f', cost)}"
    end

    def cost_per_1k_tokens(model:, input_tokens:, output_tokens:)
      total_tokens = input_tokens + output_tokens
      return 0 if total_tokens == 0

      cost = calculate_cost(model: model, input_tokens: input_tokens, output_tokens: output_tokens)
      (cost[:total] / total_tokens) * 1000
    end

    # Compare costs between models
    def compare_models(input_tokens:, output_tokens:)
      results = {}
      
      MODELS.each do |model, _pricing|
        cost = calculate_cost(
          model: model,
          input_tokens: input_tokens,
          output_tokens: output_tokens
        )
        results[model] = cost
      end

      results.sort_by { |_, cost| cost[:total] }
    end

    # Estimate monthly costs
    def estimate_monthly_cost(model:, daily_input_tokens:, daily_output_tokens:, days: 30)
      daily_cost = calculate_cost(
        model: model,
        input_tokens: daily_input_tokens,
        output_tokens: daily_output_tokens
      )

      {
        daily: daily_cost[:total],
        monthly: daily_cost[:total] * days,
        yearly: daily_cost[:total] * 365
      }
    end
  end
end