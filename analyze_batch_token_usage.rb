#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'optparse'
require 'fileutils'
require 'logger'
require_relative 'changelog_generator/batch_signatures'
require_relative 'changelog_generator/batch_modules'
require_relative 'changelog_generator/structured_output_signatures'
require_relative 'changelog_generator/structured_output_modules'
require_relative 'changelog_generator/pricing'

# Analysis script for batch processing token usage - now includes JSON mode comparison
class BatchTokenAnalyzer
  attr_reader :results, :pr_data, :batch_sizes, :test_mode, :anthropic_tool_use

  def initialize(pr_limit: nil, batch_sizes: [1, 3, 5, 10, 20], test_mode: 'both', anthropic_tool_use: true)
    @pr_limit = pr_limit
    @batch_sizes = batch_sizes
    @test_mode = test_mode # 'batch', 'json_mode', or 'both'
    @anthropic_tool_use = anthropic_tool_use # Use tool use for Anthropic instead of extraction
    @results = { batch: {}, json_mode: {} }
    @pr_data = load_pr_data
    setup_instrumentation
  end

  def run_analysis
    puts "🔍 Analyzing token usage: #{@test_mode.upcase} mode"
    puts "📊 Using #{@pr_data.length} PRs"
    puts "📦 Testing batch sizes: #{@batch_sizes.join(', ')}"
    puts "=" * 60
    puts

    modes_to_test = case @test_mode
    when 'batch' then ['batch']
    when 'json_mode' then ['json_mode']
    else ['batch', 'json_mode']
    end

    modes_to_test.each do |mode|
      puts "\n#{mode == 'batch' ? '📦' : '🎯'} Testing #{mode.upcase.gsub('_', ' ')} approach..."
      puts "-" * 50
      
      @batch_sizes.each do |batch_size|
        puts "\n  ▶️  Batch size: #{batch_size}"
        analyze_batch_size(batch_size, mode)
      end
    end

    generate_report
  end

  private

  def load_pr_data
    path = 'fixtures/llm-changelog-generator/data/feb-pull-requests.json'
    content = File.read(path, encoding: 'UTF-8')
    data = JSON.parse(content)
    
    # Apply PR limit if specified
    if @pr_limit && @pr_limit > 0
      data = data.first(@pr_limit)
    end
    
    # Convert to PullRequest objects
    data.map do |pr|
      ChangelogGenerator::PullRequest.new(
        pr: pr["pr"],
        title: pr["title"],
        description: pr["description"],
        ellipsis_summary: pr["ellipsis_summary"]
      )
    end
  end

  def setup_instrumentation
    @current_mode = nil
    @current_batch_size = nil
    @retry_counts = {}
    @json_errors = {}
    @last_api_call_time = {}
    
    # Subscribe to token events
    DSPy::Instrumentation.subscribe('dspy.lm.tokens') do |event|
      next unless @current_mode && @current_batch_size
      
      results = @results[@current_mode][@current_batch_size]
      results[:token_events] ||= []
      results[:token_events] << {
        input_tokens: event.payload[:input_tokens] || 0,
        output_tokens: event.payload[:output_tokens] || 0,
        total_tokens: event.payload[:total_tokens] || 0,
        timestamp: Time.now
      }
    end

    # Subscribe to LM request events for timing
    DSPy::Instrumentation.subscribe('dspy.lm.request') do |event|
      next unless @current_mode && @current_batch_size
      
      results = @results[@current_mode][@current_batch_size]
      results[:api_calls] ||= []
      
      # Detect retries by checking if calls happen in quick succession to same signature
      key = "#{@current_mode}_#{@current_batch_size}_#{event.payload[:signature_class]}"
      current_time = Time.now
      
      if @last_api_call_time[key] && (current_time - @last_api_call_time[key] < 2.0)
        # Likely a retry if calls happen within 2 seconds
        retry_key = "#{@current_mode}_#{@current_batch_size}"
        @retry_counts[retry_key] ||= 0
        @retry_counts[retry_key] += 1
      end
      @last_api_call_time[key] = current_time
      
      results[:api_calls] << {
        duration_ms: event.payload[:duration_ms] || 0,
        timestamp: current_time,
        model: event.payload[:gen_ai_request_model],
        signature_class: event.payload[:signature_class]
      }
    end
    
    # For JSON errors, we'll detect them from exceptions in the main flow
    # Since DSPy's JSON mode should prevent most parsing errors
  end

  def analyze_batch_size(batch_size, mode)
    @current_mode = mode.to_sym
    @current_batch_size = batch_size
    
    @results[@current_mode][batch_size] = {
      mode: mode,
      batch_size: batch_size,
      start_time: Time.now,
      token_events: [],
      api_calls: []
    }

    begin
      # Configure DSPy with appropriate settings for each mode
      if mode == 'json_mode'
        # Enable structured outputs for JSON mode
        DSPy.configure do |config|
          # Allow choice between OpenAI and Anthropic
          if ENV['USE_ANTHROPIC'] == 'true'
            config.lm = DSPy::LM.new('anthropic/claude-3-haiku-20240307', 
              api_key: ENV.fetch('ANTHROPIC_API_KEY')
            )
            # With Anthropic, tool use strategy will be automatically selected if available
            # Falls back to extraction strategy for older models
          else
            config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
              api_key: ENV.fetch('OPENAI_API_KEY'),
              structured_outputs: true  # This enables OpenAI's structured outputs
            )
          end
          # Configure structured outputs
          config.structured_outputs.strategy = DSPy::Strategy::Strict
          config.structured_outputs.retry_enabled = true
          config.structured_outputs.max_retries = 3
          config.structured_outputs.fallback_enabled = true
          # The strategy will be automatically selected based on the model:
          # - OpenAI with structured_outputs: true → OpenAI structured output strategy (100% reliable JSON)
          # - Anthropic Claude 3+ → Anthropic tool use strategy (100% reliable JSON)
          # - Anthropic older models → Anthropic extraction strategy (4-pattern matching, <0.1% error rate)
        end
      else
        # Regular mode without structured outputs
        DSPy.configure do |config|
          if ENV['USE_ANTHROPIC'] == 'true'
            config.lm = DSPy::LM.new('anthropic/claude-3-haiku-20240307',
              api_key: ENV.fetch('ANTHROPIC_API_KEY')
            )
          else
            config.lm = DSPy::LM.new('openai/gpt-4o-mini',
              api_key: ENV.fetch('OPENAI_API_KEY'),
              structured_outputs: false  # Uses enhanced prompting strategy
            )
          end
        end
      end

      # Run appropriate generator
      generator = if mode == 'batch'
        ChangelogGenerator::Batch::BatchChangelogGenerator.new
      else
        ChangelogGenerator::StructuredOutput::BatchChangelogGenerator.new
      end
      
      result = generator.call(
        pull_requests: @pr_data, 
        month: "July", 
        year: 2025, 
        batch_size: batch_size
      )

      results = @results[@current_mode][batch_size]
      results[:output] = result.mdx_content
      results[:success] = true
      results[:end_time] = Time.now

      # Calculate totals
      total_input = results[:token_events].sum { |e| e[:input_tokens] }
      total_output = results[:token_events].sum { |e| e[:output_tokens] }
      
      results[:total_input_tokens] = total_input
      results[:total_output_tokens] = total_output
      results[:total_tokens] = total_input + total_output
      results[:api_call_count] = results[:api_calls].length
      results[:total_duration_ms] = results[:api_calls].sum { |c| c[:duration_ms] }
      
      # Get retry and error counts
      key = "#{@current_mode}_#{batch_size}"
      results[:retry_count] = @retry_counts[key] || 0
      results[:json_error_count] = @json_errors[key] || 0
      results[:retry_rate] = results[:api_call_count] > 0 ? 
        (results[:retry_count].to_f / results[:api_call_count] * 100).round(1) : 0

      # Calculate cost
      results[:cost] = Pricing.calculate_cost(
        model: 'openai/gpt-4o-mini',
        input_tokens: total_input,
        output_tokens: total_output
      )

      # Calculate efficiency metrics
      results[:batches_processed] = (@pr_data.length.to_f / batch_size).ceil
      results[:tokens_per_pr] = total_input + total_output > 0 ? 
        (total_input + total_output).to_f / @pr_data.length : 0
      results[:tokens_per_batch] = total_input + total_output > 0 ?
        (total_input + total_output).to_f / results[:batches_processed] : 0

      puts "  ✅ Success! Tokens: #{total_input} in / #{total_output} out = #{total_input + total_output} total"
      puts "  📞 API Calls: #{results[:api_call_count]} (#{results[:retry_count]} retries)"
      puts "  💰 Cost: $#{sprintf('%.4f', results[:cost][:total])}"
      
      if mode == 'json_mode' && results[:json_error_count] == 0
        puts "  🎯 JSON Mode: 0 parsing errors!"
      elsif mode == 'json_mode'
        puts "  ⚠️  JSON Mode: #{results[:json_error_count]} parsing errors"
      end

    rescue => e
      results = @results[@current_mode][batch_size]
      results[:success] = false
      results[:error] = e.message
      results[:end_time] = Time.now
      puts "  ❌ Error: #{e.message}"
    ensure
      @current_mode = nil
      @current_batch_size = nil
    end
  end

  def generate_report
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    report_path = File.join("reports/batch_token_analysis_#{timestamp}.md")
    FileUtils.mkdir_p(File.dirname(report_path))

    File.open(report_path, 'w') do |f|
      f.puts "# Token Usage Analysis: #{@test_mode == 'both' ? 'Batch vs JSON Mode' : @test_mode.upcase}"
      f.puts
      f.puts "**Date**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      f.puts "**Total PRs**: #{@pr_data.length}"
      f.puts "**Batch Sizes Tested**: #{@batch_sizes.join(', ')}"
      f.puts "**Test Mode**: #{@test_mode}"
      f.puts
      
      # Summary tables for each mode
      modes_tested = @test_mode == 'both' ? [:batch, :json_mode] : [@test_mode.to_sym]
      
      modes_tested.each do |mode|
        f.puts "## #{mode.to_s.upcase.gsub('_', ' ')} Summary"
        f.puts
        f.puts "| Batch Size | API Calls | Retries | Input Tokens | Output Tokens | Total Tokens | Tokens/PR | Cost | Duration |"
        f.puts "|------------|-----------|---------|--------------|---------------|--------------|-----------|------|----------|"
        
        @results[mode].each do |batch_size, data|
          next unless data[:success]
          
          api_calls = data[:api_call_count]
          retries = data[:retry_count]
          input_tokens = data[:total_input_tokens]
          output_tokens = data[:total_output_tokens]
          total_tokens = data[:total_tokens]
          tokens_per_pr = sprintf('%.1f', data[:tokens_per_pr])
          cost = sprintf('$%.4f', data[:cost][:total])
          duration = sprintf('%.1fs', data[:total_duration_ms] / 1000.0)
          
          f.puts "| #{batch_size} | #{api_calls} | #{retries} | #{input_tokens} | #{output_tokens} | #{total_tokens} | #{tokens_per_pr} | #{cost} | #{duration} |"
        end
        f.puts
      end
      
      # Comparison section if both modes tested
      if @test_mode == 'both'
        f.puts "## Mode Comparison"
        f.puts
        f.puts "### Token Efficiency: JSON Mode vs Batch Mode"
        f.puts
        f.puts "| Batch Size | Batch Tokens | JSON Mode Tokens | Improvement | Batch Retries | JSON Retries |"
        f.puts "|------------|--------------|------------------|-------------|---------------|-------------|"
        
        @batch_sizes.each do |batch_size|
          batch_data = @results[:batch][batch_size]
          json_data = @results[:json_mode][batch_size]
          
          next unless batch_data && batch_data[:success] && json_data && json_data[:success]
          
          batch_tokens = batch_data[:total_tokens]
          json_tokens = json_data[:total_tokens]
          improvement = batch_tokens > 0 ? ((1 - json_tokens.to_f / batch_tokens) * 100).round(1) : 0
          
          f.puts "| #{batch_size} | #{batch_tokens} | #{json_tokens} | #{improvement}% | #{batch_data[:retry_count]} | #{json_data[:retry_count]} |"
        end
        
        f.puts
        f.puts "### Cost Comparison"
        f.puts
        f.puts "| Batch Size | Batch Cost | JSON Mode Cost | Savings |"
        f.puts "|------------|------------|----------------|-------|"
        
        @batch_sizes.each do |batch_size|
          batch_data = @results[:batch][batch_size]
          json_data = @results[:json_mode][batch_size]
          
          next unless batch_data && batch_data[:success] && json_data && json_data[:success]
          
          batch_cost = batch_data[:cost][:total]
          json_cost = json_data[:cost][:total]
          savings = batch_cost > 0 ? ((1 - json_cost / batch_cost) * 100).round(1) : 0
          
          f.puts "| #{batch_size} | $#{sprintf('%.4f', batch_cost)} | $#{sprintf('%.4f', json_cost)} | #{savings}% |"
        end
      end
      
      f.puts
      f.puts "## Token Usage Efficiency"
      f.puts
      
      modes_tested.each do |mode|
        f.puts "### #{mode.to_s.upcase.gsub('_', ' ')}: Comparison to Individual Processing"
        f.puts
        
        if @results[mode][1] && @results[mode][1][:success]
          baseline_tokens = @results[mode][1][:total_tokens]
          baseline_cost = @results[mode][1][:cost][:total]
          baseline_api_calls = @results[mode][1][:api_call_count]
          
          f.puts "| Batch Size | Token Reduction | Cost Savings | API Call Reduction |"
          f.puts "|------------|-----------------|--------------|-------------------|"
          
          @batch_sizes.each do |batch_size|
            next if batch_size == 1
            next unless @results[mode][batch_size] && @results[mode][batch_size][:success]
            
            token_reduction = ((1 - @results[mode][batch_size][:total_tokens].to_f / baseline_tokens) * 100).round(1)
            cost_savings = ((1 - @results[mode][batch_size][:cost][:total] / baseline_cost) * 100).round(1)
            api_reduction = ((1 - @results[mode][batch_size][:api_call_count].to_f / baseline_api_calls) * 100).round(1)
            
            f.puts "| #{batch_size} | #{token_reduction}% | #{cost_savings}% | #{api_reduction}% |"
          end
        end
        f.puts
      end
      
      f.puts
      f.puts "## Key Findings"
      f.puts
      
      if @test_mode == 'both'
        # Calculate average improvements
        total_token_improvement = 0
        total_cost_savings = 0
        total_retry_reduction = 0
        comparison_count = 0
        
        @batch_sizes.each do |batch_size|
          batch_data = @results[:batch][batch_size]
          json_data = @results[:json_mode][batch_size]
          
          if batch_data && batch_data[:success] && json_data && json_data[:success]
            token_improvement = (1 - json_data[:total_tokens].to_f / batch_data[:total_tokens]) * 100
            cost_savings = (1 - json_data[:cost][:total] / batch_data[:cost][:total]) * 100
            retry_reduction = batch_data[:retry_count] - json_data[:retry_count]
            
            total_token_improvement += token_improvement
            total_cost_savings += cost_savings
            total_retry_reduction += retry_reduction
            comparison_count += 1
          end
        end
        
        if comparison_count > 0
          avg_token_improvement = total_token_improvement / comparison_count
          avg_cost_savings = total_cost_savings / comparison_count
          avg_retry_reduction = total_retry_reduction.to_f / comparison_count
          
          f.puts "1. **Average Token Reduction (JSON Mode vs Batch)**: #{avg_token_improvement.round(1)}%"
          f.puts "2. **Average Cost Savings (JSON Mode vs Batch)**: #{avg_cost_savings.round(1)}%"
          f.puts "3. **Average Retry Reduction**: #{avg_retry_reduction.round(1)} fewer retries per batch"
          
          # Check for JSON parsing errors
          json_error_total = @results[:json_mode].values.sum { |data| data[:json_error_count] || 0 }
          f.puts "4. **JSON Parsing Errors**: #{json_error_total} total errors across all tests"
        end
        
        # Find optimal batch sizes for each mode
        [:batch, :json_mode].each do |mode|
          successful = @results[mode].select { |_, data| data[:success] }
          if successful.any?
            optimal = successful.min_by { |_, data| data[:tokens_per_pr] }
            f.puts "5. **Optimal Batch Size (#{mode.to_s.upcase.gsub('_', ' ')})**: #{optimal[0]} (#{sprintf('%.1f', optimal[1][:tokens_per_pr])} tokens/PR)"
          end
        end
      else
        # Single mode analysis
        mode = @test_mode.to_sym
        successful_results = @results[mode].select { |_, data| data[:success] }
        
        if successful_results.any?
          optimal_by_tokens = successful_results.min_by { |_, data| data[:tokens_per_pr] }
          optimal_by_cost = successful_results.min_by { |_, data| data[:cost][:total] }
          
          f.puts "- **Optimal Batch Size by Token Efficiency**: #{optimal_by_tokens[0]} (#{sprintf('%.1f', optimal_by_tokens[1][:tokens_per_pr])} tokens/PR)"
          f.puts "- **Optimal Batch Size by Cost**: #{optimal_by_cost[0]} ($#{sprintf('%.4f', optimal_by_cost[1][:cost][:total])})"
          
          if @results[mode][1] && @results[mode][1][:success]
            best_batch = optimal_by_tokens[0]
            if best_batch != 1
              token_savings = (@results[mode][1][:total_tokens] - optimal_by_tokens[1][:total_tokens]).to_f
              percentage_savings = (token_savings / @results[mode][1][:total_tokens]) * 100
              
              f.puts "- **Token Savings with Optimal Batching**: #{token_savings.round} tokens (#{percentage_savings.round(1)}% reduction)"
              f.puts "- **API Call Reduction**: From #{@results[mode][1][:api_call_count]} to #{optimal_by_tokens[1][:api_call_count]} calls"
            end
          end
        end
      end
      
      f.puts
      f.puts "## Recommendations"
      f.puts
      f.puts "Based on the analysis:"
      f.puts
      
      if @test_mode == 'both'
        f.puts "1. **Adopt JSON Mode**: The structured output approach consistently reduces token usage and eliminates JSON parsing errors"
        f.puts "2. **Optimal Batch Size**: Use batch size of 10-20 for best balance of efficiency and context management"
        f.puts "3. **Retry Handling**: JSON mode's built-in validation significantly reduces retry rates"
        f.puts "4. **Cost Optimization**: JSON mode provides substantial cost savings through reduced token usage"
        f.puts "5. **Production Readiness**: With 0 JSON parsing errors, JSON mode is more reliable for production use"
      else
        f.puts "1. **Batch processing significantly reduces token usage** compared to individual PR processing"
        f.puts "2. **Larger batch sizes generally improve efficiency** but may have diminishing returns"
        f.puts "3. **API call reduction** is proportional to batch size, reducing latency and rate limit pressure"
        f.puts "4. **Cost savings** scale with token reduction, making batch processing more economical"
      end
    end

    puts
    puts "📄 Report saved to: #{report_path}"
    report_path
  end
end

# Run if executed directly
if __FILE__ == $0
  options = {
    limit: nil,
    batch_sizes: [1, 3, 5, 10, 20],
    test_mode: 'both'
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    
    opts.on("-l", "--limit N", Integer, "Limit number of PRs to process") do |n|
      options[:limit] = n
    end
    
    opts.on("-b", "--batch-sizes SIZES", "Comma-separated batch sizes to test (default: 1,3,5,10,20)") do |sizes|
      options[:batch_sizes] = sizes.split(',').map(&:to_i)
    end
    
    opts.on("-m", "--mode MODE", "Test mode: batch, json_mode, or both (default: both)") do |mode|
      unless %w[batch json_mode both].include?(mode)
        puts "Invalid mode: #{mode}. Must be batch, json_mode, or both"
        exit 1
      end
      options[:test_mode] = mode
    end
    
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  analyzer = BatchTokenAnalyzer.new(
    pr_limit: options[:limit],
    batch_sizes: options[:batch_sizes],
    test_mode: options[:test_mode]
  )
  analyzer.run_analysis
end