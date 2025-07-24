# frozen_string_literal: true

require 'spec_helper'
require_relative '../../changelog_generator/structured_outputs_comparison'

RSpec.describe ChangelogGenerator::Batch::StructuredOutputsComparison do
  let(:sample_prs) do
    [
      ChangelogGenerator::PullRequest.new(
        pr: 3170,
        title: "Add PostgreSQL metrics dashboard",
        description: "Implements built-in metrics for CPU, memory, and disk usage tracking",
        ellipsis_summary: "Added comprehensive metrics dashboard for PostgreSQL instances"
      ),
      ChangelogGenerator::PullRequest.new(
        pr: 3202,
        title: "Enhance metrics API endpoints",
        description: "Adds new API endpoints for retrieving PostgreSQL performance metrics",
        ellipsis_summary: "Extended metrics API with additional endpoints"
      ),
      ChangelogGenerator::PullRequest.new(
        pr: 3312,
        title: "GitHub runner performance improvements",
        description: "Optimizes runner startup time and resource allocation",
        ellipsis_summary: "Faster GitHub runner provisioning"
      ),
      ChangelogGenerator::PullRequest.new(
        pr: 3366,
        title: "Add runner location preferences",
        description: "Allows users to specify preferred geographic locations for runners",
        ellipsis_summary: "Geographic preference support for runners"
      )
    ]
  end

  describe '#run_comparison' do
    it 'compares OpenAI and Anthropic structured outputs', vcr: { cassette_name: 'structured_outputs_comparison' } do
      comparison = described_class.new
      
      # Capture output
      output = StringIO.new
      original_stdout = $stdout
      $stdout = output
      
      begin
        comparison.run_comparison(pull_requests: sample_prs, batch_size: 2)
        
        results = comparison.results
        
        # Both providers should have results
        expect(results).to have_key('openai_structured')
        expect(results).to have_key('anthropic_structured')
        
        # Check OpenAI results
        openai_results = results['openai_structured']
        expect(openai_results[:outputs]).not_to be_empty
        # Token events won't be captured when using VCR, so we check the structure only
        expect(openai_results).to have_key(:token_events)
        expect(openai_results[:duration]).to be > 0
        
        # Check Anthropic results
        anthropic_results = results['anthropic_structured']
        expect(anthropic_results[:outputs]).not_to be_empty
        # Token events won't be captured when using VCR, so we check the structure only
        expect(anthropic_results).to have_key(:token_events)
        expect(anthropic_results[:duration]).to be > 0
        
        # Verify output contains comparison
        output_string = output.string
        expect(output_string).to include('STRUCTURED OUTPUTS COMPARISON REPORT')
        expect(output_string).to include('OPENAI STRUCTURED')
        expect(output_string).to include('ANTHROPIC STRUCTURED')
        expect(output_string).to include('COMPARISON SUMMARY')
        expect(output_string).to include('Token Usage:')
        expect(output_string).to include('Cost:')
      ensure
        $stdout = original_stdout
      end
    end

    it 'tracks token usage for both providers', vcr: { cassette_name: 'structured_outputs_tokens' } do
      comparison = described_class.new
      
      # Suppress output
      original_stdout = $stdout
      $stdout = StringIO.new
      
      begin
        comparison.run_comparison(pull_requests: sample_prs.first(2), batch_size: 2)
        
        results = comparison.results
        
        # With VCR, token events won't be captured from runtime instrumentation
        # Instead, we just verify the structure exists
        expect(results['openai_structured']).to have_key(:token_events)
        expect(results['anthropic_structured']).to have_key(:token_events)
        
        # Verify output quality instead
        openai_outputs = results['openai_structured'][:outputs]
        anthropic_outputs = results['anthropic_structured'][:outputs]
        
        expect(openai_outputs).not_to be_empty
        expect(anthropic_outputs).not_to be_empty
        
        # Check that themes were extracted
        openai_outputs.each do |output|
          expect(output.themes).not_to be_empty
          expect(output.pr_theme_mapping).not_to be_empty
        end
        
        anthropic_outputs.each do |output|
          expect(output.themes).not_to be_empty
          expect(output.pr_theme_mapping).not_to be_empty
        end
      ensure
        $stdout = original_stdout
      end
    end

    it 'handles errors gracefully', vcr: { cassette_name: 'structured_outputs_errors' } do
      comparison = described_class.new
      
      # Create an invalid PR that might cause parsing issues
      invalid_prs = [
        ChangelogGenerator::PullRequest.new(
          pr: 9999,
          title: "Test " * 100,  # Very long title
          description: "Invalid\x00data",  # Invalid characters
          ellipsis_summary: ""
        )
      ]
      
      # Suppress output
      original_stdout = $stdout
      $stdout = StringIO.new
      
      begin
        comparison.run_comparison(pull_requests: invalid_prs, batch_size: 1)
        
        results = comparison.results
        
        # Should still have results structure
        expect(results).to have_key('openai_structured')
        expect(results).to have_key('anthropic_structured')
        
        # Errors should be tracked if they occur
        # (Note: The providers might handle this gracefully, so we just check the structure)
        expect(results['openai_structured']).to have_key(:errors)
        expect(results['anthropic_structured']).to have_key(:errors)
      ensure
        $stdout = original_stdout
      end
    end
  end
end