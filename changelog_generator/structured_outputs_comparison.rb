# frozen_string_literal: true

require 'bundler/setup'
require 'dspy'
require 'json'
require 'ostruct'
require_relative 'batch_signatures'
require_relative 'pricing'
include Pricing

module ChangelogGenerator
  module Batch
    # Compares OpenAI Structured Outputs vs Anthropic's approach
    # for the same changelog generation task
    class StructuredOutputsComparison
      attr_reader :results

      def initialize
        @results = {}
        setup_instrumentation
      end

      def run_comparison(pull_requests:, batch_size: 5)
        puts "🔬 Comparing Structured Outputs: OpenAI vs Anthropic"
        puts "📊 Using #{pull_requests.length} PRs in batches of #{batch_size}"
        puts

        # Test with OpenAI
        test_openai_structured(pull_requests, batch_size)
        
        # Test with Anthropic
        test_anthropic_structured(pull_requests, batch_size)
        
        # Generate comparison report
        generate_report
      end

      private

      def test_openai_structured(pull_requests, batch_size)
        puts "▶️  Testing OpenAI Structured Outputs..."
        
        # Configure for OpenAI with structured outputs enabled
        openai_lm = DSPy::LM.new(
          'openai/gpt-4o-mini',
          api_key: ENV.fetch('OPENAI_API_KEY'),
          structured_outputs: true
        )
        
        DSPy.configure do |config|
          config.lm = openai_lm
          # OpenAI uses structured outputs directly via the LM configuration
          config.structured_outputs.openai = true
          config.structured_outputs.retry_enabled = true
          config.structured_outputs.max_retries = 3
        end
        
        @current_provider = 'openai_structured'
        @results[@current_provider] = {
          start_time: Time.now,
          token_events: [],
          errors: [],
          outputs: []
        }
        
        analyzer = BatchPRAnalyzerModule.new
        
        pull_requests.each_slice(batch_size) do |batch|
          begin
            result = analyzer.call(pr_batch: batch)
            @results[@current_provider][:outputs] << result
          rescue => e
            @results[@current_provider][:errors] << {
              batch_size: batch.size,
              error: e.message,
              backtrace: e.backtrace.first(5)
            }
          end
        end
        
        @results[@current_provider][:end_time] = Time.now
        @results[@current_provider][:duration] = @results[@current_provider][:end_time] - @results[@current_provider][:start_time]
      end

      def test_anthropic_structured(pull_requests, batch_size)
        puts "\n▶️  Testing Anthropic Structured Outputs..."
        
        # Configure for Anthropic (uses enhanced extraction)
        anthropic_lm = DSPy::LM.new(
          'anthropic/claude-3-5-haiku-latest',
          api_key: ENV.fetch('ANTHROPIC_API_KEY')
        )
        
        DSPy.configure do |config|
          config.lm = anthropic_lm
          # Anthropic uses enhanced extraction (4-pattern matching)
          config.structured_outputs.anthropic = false  # Not yet available
          config.structured_outputs.retry_enabled = true
          config.structured_outputs.max_retries = 3
          config.structured_outputs.fallback_enabled = true
        end
        
        @current_provider = 'anthropic_structured'
        @results[@current_provider] = {
          start_time: Time.now,
          token_events: [],
          errors: [],
          outputs: []
        }
        
        analyzer = BatchPRAnalyzerModule.new
        
        pull_requests.each_slice(batch_size) do |batch|
          begin
            result = analyzer.call(pr_batch: batch)
            @results[@current_provider][:outputs] << result
          rescue => e
            @results[@current_provider][:errors] << {
              batch_size: batch.size,
              error: e.message,
              backtrace: e.backtrace.first(5)
            }
          end
        end
        
        @results[@current_provider][:end_time] = Time.now
        @results[@current_provider][:duration] = @results[@current_provider][:end_time] - @results[@current_provider][:start_time]
      end

      def setup_instrumentation
        # Token tracking doesn't work with VCR - see https://github.com/vicentereig/dspy.rb/issues/48
        # For now, we'll just initialize empty arrays for token events
      end

      def generate_report
        puts "\n" + "="*60
        puts "📊 STRUCTURED OUTPUTS COMPARISON REPORT"
        puts "="*60
        
        @results.each do |provider, data|
          puts "\n### #{provider.upcase.gsub('_', ' ')}"
          puts "-" * 40
          
          # Token usage
          total_input = data[:token_events].sum { |e| e[:input_tokens] }
          total_output = data[:token_events].sum { |e| e[:output_tokens] }
          total_tokens = data[:token_events].sum { |e| e[:total_tokens] }
          
          puts "⏱️  Duration: #{data[:duration]&.round(2)}s"
          puts "📥 Input tokens: #{total_input}"
          puts "📤 Output tokens: #{total_output}"
          puts "🔢 Total tokens: #{total_tokens}"
          
          # Calculate costs
          if provider.include?('openai')
            model_name = 'openai/gpt-4o-mini'
          else
            model_name = 'anthropic/claude-3-5-haiku-latest'
          end
          
          begin
            cost_info = Pricing.calculate_cost(
              model: model_name,
              input_tokens: total_input,
              output_tokens: total_output
            )
            
            puts "💰 Cost: $#{cost_info[:total].round(4)} (input: $#{cost_info[:input_cost].round(4)}, output: $#{cost_info[:output_cost].round(4)})"
          rescue => e
            puts "💰 Cost: Unable to calculate (#{e.message})"
          end
          
          # Success rate
          total_batches = data[:outputs].size + data[:errors].size
          success_rate = total_batches > 0 ? (data[:outputs].size.to_f / total_batches * 100).round(1) : 0
          
          puts "✅ Success rate: #{success_rate}% (#{data[:outputs].size}/#{total_batches} batches)"
          
          # Errors
          if data[:errors].any?
            puts "❌ Errors: #{data[:errors].size}"
            data[:errors].first(3).each do |error|
              puts "   - #{error[:error]}"
            end
          end
          
          # Output quality check
          if data[:outputs].any?
            puts "\n📋 Output Quality:"
            
            # Check if themes were identified
            themes_identified = data[:outputs].sum { |o| o.themes.size }
            puts "   - Themes identified: #{themes_identified}"
            
            # Check structure consistency
            valid_structures = data[:outputs].count { |o| 
              o.themes.all? { |t| t.name && t.description && t.pr_ids }
            }
            puts "   - Valid theme structures: #{valid_structures}/#{data[:outputs].size}"
            
            # Sample theme names
            all_theme_names = data[:outputs].flat_map { |o| o.themes.map(&:name) }.uniq
            puts "   - Sample themes: #{all_theme_names.first(3).join(', ')}"
          end
        end
        
        # Comparison summary
        puts "\n" + "="*60
        puts "📊 COMPARISON SUMMARY"
        puts "="*60
        
        if @results.size == 2
          openai_data = @results['openai_structured']
          anthropic_data = @results['anthropic_structured']
          
          if openai_data && anthropic_data
            # Token efficiency
            openai_tokens = openai_data[:token_events].sum { |e| e[:total_tokens] }
            anthropic_tokens = anthropic_data[:token_events].sum { |e| e[:total_tokens] }
            
            token_diff = ((anthropic_tokens - openai_tokens).to_f / openai_tokens * 100).round(1)
            puts "\n🔢 Token Usage:"
            puts "   OpenAI: #{openai_tokens} tokens"
            puts "   Anthropic: #{anthropic_tokens} tokens"
            puts "   Difference: #{token_diff > 0 ? '+' : ''}#{token_diff}%"
            
            # Speed comparison
            if openai_data[:duration] && anthropic_data[:duration]
              speed_diff = ((anthropic_data[:duration] - openai_data[:duration]) / openai_data[:duration] * 100).round(1)
              puts "\n⏱️  Speed:"
              puts "   OpenAI: #{openai_data[:duration].round(2)}s"
              puts "   Anthropic: #{anthropic_data[:duration].round(2)}s"
              puts "   Difference: #{speed_diff > 0 ? '+' : ''}#{speed_diff}%"
            end
            
            # Reliability
            openai_success = openai_data[:outputs].size.to_f / (openai_data[:outputs].size + openai_data[:errors].size) * 100
            anthropic_success = anthropic_data[:outputs].size.to_f / (anthropic_data[:outputs].size + anthropic_data[:errors].size) * 100
            
            puts "\n✅ Reliability:"
            puts "   OpenAI: #{openai_success.round(1)}% success rate"
            puts "   Anthropic: #{anthropic_success.round(1)}% success rate"
            
            # Cost comparison
            openai_cost = calculate_provider_cost('openai/gpt-4o-mini', openai_data[:token_events])
            anthropic_cost = calculate_provider_cost('anthropic/claude-3-5-haiku-latest', anthropic_data[:token_events])
            
            if openai_cost && anthropic_cost
              cost_diff = ((anthropic_cost - openai_cost) / openai_cost * 100).round(1)
              puts "\n💰 Cost:"
              puts "   OpenAI: $#{openai_cost.round(4)}"
              puts "   Anthropic: $#{anthropic_cost.round(4)}"
              puts "   Difference: #{cost_diff > 0 ? '+' : ''}#{cost_diff}%"
            end
          end
        end
        
        puts "\n" + "="*60
      end

      def calculate_provider_cost(model_name, token_events)
        total_input = token_events.sum { |e| e[:input_tokens] }
        total_output = token_events.sum { |e| e[:output_tokens] }
        
        begin
          cost_info = Pricing.calculate_cost(
            model: model_name,
            input_tokens: total_input,
            output_tokens: total_output
          )
          cost_info[:total]
        rescue => e
          nil
        end
      end
    end
  end
end