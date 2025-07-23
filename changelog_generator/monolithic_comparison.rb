#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dspy'
require 'json'
require 'fileutils'
require 'time'
require_relative 'pricing'
require_relative 'signatures'
require_relative 'modules'

# Simple signature for raw prompting
class RawPromptSignature < DSPy::Signature
  description "Generate changelog from PRs using provided prompt"
  
  input do
    const :prompt, String, description: "The prompt template"
    const :pr_data, String, description: "JSON data of PRs"
  end
  
  output do
    const :changelog, String, description: "Generated changelog in MDX format"
  end
end

class MonolithicComparison
  attr_reader :results, :pr_data

  MODELS = {
    'claude-opus-4' => {
      model: 'anthropic/claude-opus-4-20250514',
      prompt_file: 'claude-opus-4-prompt.txt'
    },
    'claude-opus-4-tweak' => {
      model: 'anthropic/claude-opus-4-20250514', 
      prompt_file: 'claude-opus-4-tweak-prompt.txt'
    },
    'openai-4o' => {
      model: 'openai/gpt-4o',
      prompt_file: 'openai-4o-prompt.txt'
    },
    'openai-o3' => {
      model: 'openai/gpt-4o', # o3 doesn't exist yet, using 4o
      prompt_file: 'openai-o3-prompt.txt'
    },
    'openai-o4-mini-high' => {
      model: 'openai/gpt-4o-mini',
      prompt_file: 'openai-o4-mini-high-prompt.txt'
    }
  }.freeze

  def initialize(month: 'May', year: 2025)
    @month = month
    @year = year
    @results = {}
    @pr_data = load_pr_data
    setup_instrumentation
  end

  def run_comparison
    puts "🚀 Running monolithic changelog generation comparison..."
    puts "📊 Using #{@pr_data.length} PRs from #{@month} #{@year}"
    puts

    MODELS.each do |name, config|
      puts "▶️  Testing #{name}..."
      run_model(name, config)
      puts
    end

    generate_report
  end

  private

  def load_pr_data
    # Load the PR data based on month
    filename = @month.downcase == 'may' ? 'may-pull-requests.json' : 'feb-pull-requests.json'
    path = File.join(__dir__, '../fixtures/llm-changelog-generator/data', filename)
    # Read with UTF-8 encoding to handle special characters
    JSON.parse(File.read(path, encoding: 'UTF-8'))
  end

  def setup_instrumentation
    # Subscribe to token events
    DSPy::Instrumentation.subscribe('dspy.lm.tokens') do |event|
      current_model = @current_model
      next unless current_model

      @results[current_model][:token_events] ||= []
      @results[current_model][:token_events] << {
        input_tokens: event.payload[:tokens_input] || 0,
        output_tokens: event.payload[:tokens_output] || 0,
        total_tokens: event.payload[:tokens_total] || 0
      }
    end

    # Subscribe to LM request events for timing
    DSPy::Instrumentation.subscribe('dspy.lm.request') do |event|
      current_model = @current_model
      next unless current_model

      @results[current_model][:duration_ms] = event.payload[:duration_ms] || 0
    end
  end

  def run_model(name, config)
    @current_model = name
    @results[name] = {
      model: config[:model],
      start_time: Time.now,
      token_events: []
    }

    begin
      # Load the prompt
      prompt_path = File.join(__dir__, '../fixtures/llm-changelog-generator/prompts', config[:prompt_file])
      prompt = File.read(prompt_path)

      # Configure DSPy with the model
      DSPy.configure do |c|
        case config[:model]
        when /anthropic/
          c.lm = DSPy::LM.new(config[:model], api_key: ENV['ANTHROPIC_API_KEY'])
        when /openai/
          c.lm = DSPy::LM.new(config[:model], api_key: ENV['OPENAI_API_KEY'])
        end
      end

      # Use Predict with the raw prompt signature
      generator = DSPy::Predict.new(RawPromptSignature)
      
      result = generator.call(
        prompt: prompt,
        pr_data: @pr_data.to_json
      )
      
      @results[name][:output] = result.changelog
      @results[name][:success] = true
      @results[name][:end_time] = Time.now

      # Calculate totals from token events
      total_input = @results[name][:token_events].sum { |e| e[:input_tokens] }
      total_output = @results[name][:token_events].sum { |e| e[:output_tokens] }
      
      @results[name][:total_input_tokens] = total_input
      @results[name][:total_output_tokens] = total_output
      @results[name][:total_tokens] = total_input + total_output

      # Calculate cost
      @results[name][:cost] = Pricing.calculate_cost(
        model: config[:model],
        input_tokens: total_input,
        output_tokens: total_output
      )

      puts "  ✅ Success! Tokens: #{total_input} in / #{total_output} out = #{total_input + total_output} total"
      puts "  💰 Cost: $#{sprintf('%.4f', @results[name][:cost][:total])}"

    rescue => e
      @results[name][:success] = false
      @results[name][:error] = e.message
      @results[name][:end_time] = Time.now
      puts "  ❌ Error: #{e.message}"
    ensure
      @current_model = nil
    end
  end

  def generate_report
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    report_path = File.join(__dir__, "../reports/monolithic_comparison_#{timestamp}.md")
    FileUtils.mkdir_p(File.dirname(report_path))

    File.open(report_path, 'w') do |f|
      f.puts "# Monolithic Changelog Generation Comparison"
      f.puts
      f.puts "**Date**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      f.puts "**PR Data**: #{@month} #{@year} (#{@pr_data.length} PRs)"
      f.puts "**Input Data Size**: #{@pr_data.to_json.length} characters"
      f.puts
      
      f.puts "## Summary Table"
      f.puts
      f.puts "| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |"
      f.puts "|-------|--------|--------------|---------------|--------------|------|----------|"
      
      total_cost = 0
      @results.each do |name, data|
        status = data[:success] ? '✅' : '❌'
        input_tokens = data[:total_input_tokens] || 0
        output_tokens = data[:total_output_tokens] || 0
        total_tokens = data[:total_tokens] || 0
        cost = data[:cost] ? sprintf('$%.4f', data[:cost][:total]) : 'N/A'
        duration = data[:duration_ms] ? "#{data[:duration_ms]}ms" : 'N/A'
        
        total_cost += data[:cost][:total] if data[:cost]
        
        f.puts "| #{name} | #{status} | #{input_tokens} | #{output_tokens} | #{total_tokens} | #{cost} | #{duration} |"
      end
      
      f.puts
      f.puts "**Total Cost**: $#{sprintf('%.4f', total_cost)}"
      f.puts
      
      f.puts "## Detailed Results"
      f.puts
      
      @results.each do |name, data|
        f.puts "### #{name}"
        f.puts
        f.puts "- **Model**: `#{data[:model]}`"
        f.puts "- **Success**: #{data[:success] ? 'Yes' : 'No'}"
        
        if data[:success]
          f.puts "- **Input Tokens**: #{data[:total_input_tokens]}"
          f.puts "- **Output Tokens**: #{data[:total_output_tokens]}"
          f.puts "- **Total Tokens**: #{data[:total_tokens]}"
          f.puts "- **Cost Breakdown**:"
          f.puts "  - Input: $#{sprintf('%.4f', data[:cost][:input_cost])}"
          f.puts "  - Output: $#{sprintf('%.4f', data[:cost][:output_cost])}"
          f.puts "  - **Total: $#{sprintf('%.4f', data[:cost][:total])}**"
          f.puts "- **Duration**: #{data[:duration_ms]}ms"
          f.puts "- **Output Length**: #{data[:output].length} characters"
          
          # Save the output
          output_path = File.join(__dir__, "../reports/outputs/#{name}_#{timestamp}.md")
          FileUtils.mkdir_p(File.dirname(output_path))
          File.write(output_path, data[:output])
          f.puts "- **Output Saved**: `reports/outputs/#{name}_#{timestamp}.md`"
        else
          f.puts "- **Error**: #{data[:error]}"
        end
        
        f.puts
      end
      
      f.puts "## Cost Analysis"
      f.puts
      f.puts "### By Provider"
      
      anthropic_cost = @results.select { |k, _| k.include?('claude') }
                              .sum { |_, v| v[:cost] ? v[:cost][:total] : 0 }
      openai_cost = @results.select { |k, _| k.include?('openai') }
                           .sum { |_, v| v[:cost] ? v[:cost][:total] : 0 }
      
      f.puts "- **Anthropic (Claude)**: $#{sprintf('%.4f', anthropic_cost)}"
      f.puts "- **OpenAI**: $#{sprintf('%.4f', openai_cost)}"
      f.puts
      
      f.puts "### Token Efficiency"
      f.puts
      f.puts "| Model | Tokens per PR | Cost per 1K tokens |"
      f.puts "|-------|---------------|-------------------|"
      
      @results.each do |name, data|
        next unless data[:success]
        
        tokens_per_pr = data[:total_tokens].to_f / @pr_data.length
        cost_per_1k = (data[:cost][:total] / data[:total_tokens].to_f) * 1000
        
        f.puts "| #{name} | #{tokens_per_pr.round(1)} | $#{sprintf('%.4f', cost_per_1k)} |"
      end
    end

    puts
    puts "📄 Report saved to: #{report_path}"
    report_path
  end
end

# Run if executed directly
if __FILE__ == $0
  comparison = MonolithicComparison.new
  comparison.run_comparison
end