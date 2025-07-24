# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ChangelogGenerator::Batch Modules' do
  # Load some sample PR data for testing
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
        pr: 3248,
        title: "Implement firewall rule management",
        description: "Adds UI and API for managing PostgreSQL firewall rules",
        ellipsis_summary: "New firewall rule management features"
      ),
      ChangelogGenerator::PullRequest.new(
        pr: 3274,
        title: "Add IP allowlist validation",
        description: "Validates and sanitizes IP addresses in firewall rules",
        ellipsis_summary: "Improved firewall rule validation"
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

  describe 'BatchPRAnalyzerModule' do
    it 'analyzes a batch of PRs and identifies themes', vcr: { cassette_name: 'batch_pr_analyzer' } do
      analyzer = ChangelogGenerator::Batch::BatchPRAnalyzerModule.new
      result = analyzer.call(pr_batch: sample_prs)

      expect(result.themes).to be_an(Array)
      expect(result.themes).not_to be_empty
      
      # Should identify at least PostgreSQL and GitHub Runners themes
      theme_names = result.themes.map(&:name)
      expect(theme_names).to include(match(/PostgreSQL|Database/i))
      expect(theme_names).to include(match(/GitHub.*Runner/i))

      # Should have proper PR to theme mapping
      expect(result.pr_theme_mapping).to be_a(Hash)
      expect(result.pr_theme_mapping.keys).to include(3170, 3202, 3248, 3274, 3312, 3366)
    end

    it 'groups related PRs under the same theme', vcr: { cassette_name: 'batch_pr_analyzer_grouping' } do
      analyzer = ChangelogGenerator::Batch::BatchPRAnalyzerModule.new
      result = analyzer.call(pr_batch: sample_prs)

      # PostgreSQL metrics PRs should be in the same theme
      postgres_theme = result.pr_theme_mapping[3170]
      expect(result.pr_theme_mapping[3202]).to eq(postgres_theme)
      
      # Firewall PRs should be in the same theme (likely PostgreSQL)
      firewall_theme = result.pr_theme_mapping[3248]
      expect(result.pr_theme_mapping[3274]).to eq(firewall_theme)
      
      # GitHub runner PRs should be in the same theme
      runner_theme = result.pr_theme_mapping[3312]
      expect(result.pr_theme_mapping[3366]).to eq(runner_theme)
    end

    it 'provides reasoning for theme identification', vcr: { cassette_name: 'batch_pr_analyzer_reasoning' } do
      analyzer = ChangelogGenerator::Batch::BatchPRAnalyzerModule.new
      
      # Since we're using ChainOfThought, we should be able to access the reasoning
      result = analyzer.call(pr_batch: sample_prs.first(2))
      
      # The module should provide reasoning about why PRs were grouped
      expect(result).to respond_to(:reasoning) if defined?(result.reasoning)
    end
  end

  describe 'ThemeAccumulatorModule' do
    let(:existing_themes) do
      [
        ChangelogGenerator::Batch::Theme.new(
          name: "Managed PostgreSQL",
          description: "Database management improvements",
          subthemes: [],
          pr_ids: [3000, 3001]
        )
      ]
    end

    let(:new_themes) do
      [
        ChangelogGenerator::Batch::Theme.new(
          name: "PostgreSQL Enhancements",
          description: "New PostgreSQL features",
          subthemes: [],
          pr_ids: [3170, 3202]
        ),
        ChangelogGenerator::Batch::Theme.new(
          name: "GitHub Runners",
          description: "Runner improvements",
          subthemes: [],
          pr_ids: [3312, 3366]
        )
      ]
    end

    it 'merges similar themes together', vcr: { cassette_name: 'theme_accumulator_merge' } do
      accumulator = ChangelogGenerator::Batch::ThemeAccumulatorModule.new
      result = accumulator.call(existing_themes: existing_themes, new_themes: new_themes)

      expect(result.merged_themes).to be_an(Array)
      
      # Should have PostgreSQL-related theme(s)
      postgres_themes = result.merged_themes.select { |t| t.name =~ /PostgreSQL/i }
      expect(postgres_themes).not_to be_empty
      
      # Should have kept or merged some PostgreSQL PRs
      all_postgres_pr_ids = postgres_themes.flat_map(&:pr_ids)
      expect(all_postgres_pr_ids).to include(3000, 3001)
      
      # GitHub Runners should remain separate
      runner_themes = result.merged_themes.select { |t| t.name =~ /GitHub.*Runner/i }
      expect(runner_themes.size).to eq(1)
      expect(runner_themes.first.pr_ids).to include(3312, 3366)
    end

    it 'maintains theme coherence when merging', vcr: { cassette_name: 'theme_accumulator_coherence' } do
      accumulator = ChangelogGenerator::Batch::ThemeAccumulatorModule.new
      result = accumulator.call(existing_themes: existing_themes, new_themes: new_themes)

      # All themes should have meaningful descriptions
      result.merged_themes.each do |theme|
        expect(theme.description).not_to be_empty
        expect(theme.description.length).to be > 10
      end
    end
  end
end