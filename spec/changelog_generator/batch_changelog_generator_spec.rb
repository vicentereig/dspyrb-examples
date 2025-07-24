# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe ChangelogGenerator::Batch::BatchChangelogGenerator do
  # Load real PR data from fixtures
  let(:may_prs_data) do
    path = File.join(__dir__, '../../fixtures/llm-changelog-generator/data/may-pull-requests.json')
    content = File.read(path, encoding: 'UTF-8')
    JSON.parse(content)
  end

  let(:pull_requests) do
    # Take first 10 PRs for testing
    may_prs_data.first(10).map do |pr_data|
      ChangelogGenerator::PullRequest.new(
        pr: pr_data['pr'],
        title: pr_data['title'],
        description: pr_data['description'] || '',
        ellipsis_summary: pr_data['ellipsis_summary'] || ''
      )
    end
  end

  describe '#call' do
    it 'generates a complete MDX changelog from PRs', vcr: { cassette_name: 'batch_changelog_integration' } do
      generator = described_class.new
      result = generator.call(
        pull_requests: pull_requests.first(2),  # Just 2 PRs for testing
        month: 'May',
        year: 2025,
        batch_size: 5
      )

      expect(result).to respond_to(:mdx_content)
      mdx = result.mdx_content

      # Should have MDX structure
      expect(mdx).to include('---')  # Frontmatter
      expect(mdx).to include('title: "May 2025"')
      expect(mdx).to include('import { PrList }')
      expect(mdx).to include('## ')  # Theme headers
      expect(mdx).to include('### ')  # Subtheme headers
      expect(mdx).to include('<PrList>')
      expect(mdx).to include('</PrList>')
    end

    it 'processes PRs in batches', vcr: { cassette_name: 'batch_processing_verification' } do
      generator = described_class.new
      
      # Spy on the batch analyzer to verify batching
      analyzer = generator.instance_variable_get(:@batch_analyzer)
      allow(analyzer).to receive(:call).and_call_original
      
      generator.call(
        pull_requests: pull_requests,
        month: 'May', 
        year: 2025,
        batch_size: 3  # Should result in 4 batches (3, 3, 3, 1)
      )

      # Verify the analyzer was called multiple times with different batches
      expect(analyzer).to have_received(:call).at_least(3).times
    end

    it 'accumulates themes across batches', vcr: { cassette_name: 'theme_accumulation_integration' } do
      generator = described_class.new
      result = generator.call(
        pull_requests: pull_requests,
        month: 'May',
        year: 2025,
        batch_size: 2  # Small batches to test accumulation
      )

      mdx = result.mdx_content
      
      # Count unique theme headers (lines starting with ##)
      theme_headers = mdx.scan(/^## (.+)$/).flatten
      expect(theme_headers).not_to be_empty
      # Should have at least one theme (might group PRs or not, depending on content)
      expect(theme_headers.uniq.size).to be >= 1
      expect(theme_headers.uniq.size).to be <= pull_requests.size
    end

    it 'generates subthemes for each theme', vcr: { cassette_name: 'subtheme_generation' } do
      generator = described_class.new
      result = generator.call(
        pull_requests: pull_requests.first(4),  # Smaller set for focused test
        month: 'May',
        year: 2025
      )

      mdx = result.mdx_content
      
      # Should have subtheme headers (### level)
      expect(mdx).to include('### ')
      
      # Each theme should have at least one subtheme
      themes = mdx.split(/^## /).drop(1)  # Split by theme headers, drop intro
      themes.each do |theme_section|
        expect(theme_section).to match(/^### /)
      end
    end

    it 'includes PR IDs in the correct format', vcr: { cassette_name: 'pr_id_formatting' } do
      generator = described_class.new
      result = generator.call(
        pull_requests: pull_requests.first(3),
        month: 'May',
        year: 2025
      )

      mdx = result.mdx_content
      
      # Verify actual PR numbers are included in PrList
      pull_requests.first(3).each do |pr|
        expect(mdx).to match(/\{?\[.*#{pr.pr}.*\]\}?/)
      end
    end
  end
end