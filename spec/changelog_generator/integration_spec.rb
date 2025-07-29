# frozen_string_literal: true

require 'json'

RSpec.describe 'ChangelogGenerator Integration' do
  let(:fixture_path) { File.join(__dir__, '../../fixtures/llm-changelog-generator/data/may-pull-requests.json') }
  let(:sample_prs_json) { File.read(fixture_path, encoding: 'UTF-8') }
  let(:sample_prs_data) { JSON.parse(sample_prs_json) }
  
  # Convert JSON data to PullRequest structs
  let(:pull_requests) do
    sample_prs_data.first(5).map do |pr_data|
      ChangelogGenerator::PullRequest.new(
        pr: pr_data['pr'],
        title: pr_data['title'],
        description: pr_data['description'],
        ellipsis_summary: pr_data['ellipsis_summary']
      )
    end
  end

  describe 'Full pipeline with real data' do
    let(:generator) { ChangelogGenerator::ModularChangelogGenerator.new }

    it 'processes real PR data successfully', :vcr do
      result = generator.call(
        pull_requests: pull_requests,
        month: 'May',
        year: 2025
      )
      
      expect(result.mdx_content).to be_a(String)
      expect(result.mdx_content).to include('May 2025')
      expect(result.mdx_content).to include('<PrList')
      
      # Should categorize Kubernetes upgrade PR correctly
      expect(result.mdx_content).to include('Kubernetes')
    end
  end

  describe 'Token usage tracking' do
    before do
      DSPy.configure do |config|
        config.instrumentation.enabled = true
        config.instrumentation.subscribers = [:logger]
      end
    end

    it 'tracks token usage for modular approach', :vcr do
      token_usage = {}
      
      # Subscribe to token events
      DSPy::Instrumentation.subscribe('dspy.lm.tokens') do |event|
        module_name = event.payload[:module] || 'unknown'
        token_usage[module_name] ||= { input: 0, output: 0 }
        token_usage[module_name][:input] += event.payload[:tokens_input] || 0
        token_usage[module_name][:output] += event.payload[:tokens_output] || 0
      end
      
      generator = ChangelogGenerator::ModularChangelogGenerator.new
      generator.call(
        pull_requests: pull_requests.first(2),
        month: 'May',
        year: 2025
      )
      
      # Should have tracked tokens for different modules
      expect(token_usage.keys).to include('PRCategorizerModule')
      expect(token_usage.values.all? { |v| v[:input] > 0 }).to be true
    end
  end
end