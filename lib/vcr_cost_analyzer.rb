# frozen_string_literal: true

require 'yaml'

class VCRCostAnalyzer
  # GPT-4o-mini pricing (as of 2024)
  INPUT_COST_PER_1K = 0.00015  # $0.150 per 1M tokens
  OUTPUT_COST_PER_1K = 0.0006  # $0.600 per 1M tokens

  def initialize(cassette_dir = 'spec/fixtures/vcr_cassettes')
    @cassette_dir = cassette_dir
  end

  # Analyze all ADE-related cassettes for cost
  def analyze_ade_cassettes
    cassette_files = find_ade_cassettes
    total_analysis = {
      total_cost: 0.0,
      total_tokens: 0,
      total_input_tokens: 0,
      total_output_tokens: 0,
      requests: 0,
      cassettes_analyzed: 0,
      model: 'gpt-4o-mini'
    }

    cassette_details = {}

    cassette_files.each do |file|
      cassette_name = File.basename(file, '.yml')
      analysis = analyze_cassette(file)
      
      if analysis[:requests] > 0
        cassette_details[cassette_name] = analysis
        total_analysis[:total_cost] += analysis[:total_cost]
        total_analysis[:total_tokens] += analysis[:total_tokens]
        total_analysis[:total_input_tokens] += analysis[:total_input_tokens]
        total_analysis[:total_output_tokens] += analysis[:total_output_tokens]
        total_analysis[:requests] += analysis[:requests]
        total_analysis[:cassettes_analyzed] += 1
      end
    end

    {
      summary: total_analysis,
      by_cassette: cassette_details,
      cost_breakdown: generate_cost_breakdown(total_analysis)
    }
  end

  # Analyze specific cassette file
  def analyze_cassette(cassette_file)
    return { error: "Cassette not found: #{cassette_file}" } unless File.exist?(cassette_file)

    cassette_data = YAML.load_file(cassette_file)
    interactions = cassette_data['http_interactions'] || []

    total_cost = 0.0
    total_tokens = 0
    total_input_tokens = 0
    total_output_tokens = 0
    requests = 0

    interactions.each do |interaction|
      next unless openai_request?(interaction)

      usage = extract_token_usage(interaction)
      next unless usage

      input_tokens = usage[:input_tokens]
      output_tokens = usage[:output_tokens]
      
      request_cost = calculate_request_cost(input_tokens, output_tokens)
      
      total_cost += request_cost
      total_tokens += (input_tokens + output_tokens)
      total_input_tokens += input_tokens
      total_output_tokens += output_tokens
      requests += 1
    end

    {
      total_cost: total_cost.round(6),
      total_tokens: total_tokens,
      total_input_tokens: total_input_tokens,
      total_output_tokens: total_output_tokens,
      requests: requests,
      cost_per_request: requests > 0 ? (total_cost / requests).round(6) : 0.0,
      cassette_file: cassette_file
    }
  end

  # Generate cost report for optimization phases
  def optimization_phase_costs
    phase_costs = {}
    
    # Map cassette patterns to phases
    phase_patterns = {
      'baseline' => ['baseline_predictor', 'debug_empty_input'],
      'optimization' => ['ade_reproducibility/optimization'],
      'integration' => ['ade_pipeline_integration'],
      'reproducibility' => ['ade_reproducibility']
    }

    phase_patterns.each do |phase, patterns|
      phase_costs[phase] = analyze_phase_cassettes(patterns)
    end

    {
      by_phase: phase_costs,
      total_optimization_cost: phase_costs.values.sum { |p| p[:total_cost] },
      recommendations: generate_cost_recommendations(phase_costs)
    }
  end

  private

  def find_ade_cassettes
    Dir.glob(File.join(@cassette_dir, '**', '*.yml')).select do |file|
      file.match?(/ade|baseline|optimization/i)
    end
  end

  def openai_request?(interaction)
    request = interaction['request']
    return false unless request

    uri = request['uri']
    uri&.include?('api.openai.com')
  end

  def extract_token_usage(interaction)
    response = interaction.dig('response', 'body', 'string')
    return nil unless response

    begin
      # Parse the JSON response string
      response_json = JSON.parse(response)
      usage = response_json['usage']
      return nil unless usage

      {
        input_tokens: usage['prompt_tokens'] || 0,
        output_tokens: usage['completion_tokens'] || 0,
        total_tokens: usage['total_tokens'] || 0
      }
    rescue JSON::ParserError
      nil
    end
  end

  def calculate_request_cost(input_tokens, output_tokens)
    input_cost = (input_tokens / 1000.0) * INPUT_COST_PER_1K
    output_cost = (output_tokens / 1000.0) * OUTPUT_COST_PER_1K
    input_cost + output_cost
  end

  def analyze_phase_cassettes(patterns)
    total_cost = 0.0
    total_requests = 0
    cassettes_found = []

    patterns.each do |pattern|
      Dir.glob(File.join(@cassette_dir, '**', "*#{pattern}*.yml")).each do |file|
        analysis = analyze_cassette(file)
        if analysis[:requests] > 0
          total_cost += analysis[:total_cost]
          total_requests += analysis[:requests]
          cassettes_found << File.basename(file, '.yml')
        end
      end
    end

    {
      total_cost: total_cost.round(6),
      requests: total_requests,
      cassettes: cassettes_found,
      cost_per_request: total_requests > 0 ? (total_cost / total_requests).round(6) : 0.0
    }
  end

  def generate_cost_breakdown(analysis)
    {
      input_cost: ((analysis[:total_input_tokens] / 1000.0) * INPUT_COST_PER_1K).round(6),
      output_cost: ((analysis[:total_output_tokens] / 1000.0) * OUTPUT_COST_PER_1K).round(6),
      avg_tokens_per_request: analysis[:requests] > 0 ? 
        (analysis[:total_tokens].to_f / analysis[:requests]).round(1) : 0.0,
      cost_per_1k_tokens: analysis[:total_tokens] > 0 ? 
        ((analysis[:total_cost] / analysis[:total_tokens]) * 1000).round(6) : 0.0
    }
  end

  def generate_cost_recommendations(phase_costs)
    total_cost = phase_costs.values.sum { |p| p[:total_cost] }
    
    recommendations = []
    
    if total_cost > 0.10
      recommendations << "Consider using fewer examples during development (current cost: $#{total_cost.round(4)})"
    end
    
    if phase_costs.dig('optimization', :cost_per_request).to_f > 0.01
      recommendations << "Optimization phase is expensive - consider caching results"
    end
    
    if phase_costs.dig('reproducibility', :requests).to_i > 20
      recommendations << "Many reproducibility tests - consider reducing redundant API calls"
    end
    
    recommendations << "Total development cost so far: $#{total_cost.round(4)}" if total_cost > 0
    
    recommendations
  end
end