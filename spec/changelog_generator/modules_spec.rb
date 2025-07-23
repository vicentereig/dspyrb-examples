# frozen_string_literal: true

RSpec.describe 'ChangelogGenerator Modules' do
  let(:sample_pr) do
    ChangelogGenerator::PullRequest.new(
      pr: 3366,
      title: "Add inline edit functionality for PostgreSQL firewall rules",
      description: "This PR adds the ability to edit firewall rules inline in the PostgreSQL management interface.",
      ellipsis_summary: "Adds inline editing for PostgreSQL firewall rules with description support"
    )
  end

  let(:internal_pr) do
    ChangelogGenerator::PullRequest.new(
      pr: 3001,
      title: "Refactor internal logging system",
      description: "Refactors the internal logging to use structured logs",
      ellipsis_summary: "Internal refactoring of logging system"
    )
  end

  describe ChangelogGenerator::PRCategorizerModule, :vcr do
    let(:categorizer) { described_class.new }

    it 'categorizes customer-facing PRs correctly' do
      result = categorizer.call(pull_request: sample_pr)
      
      expect(result.category).to eq(ChangelogGenerator::PRCategory::CustomerFacingAvailable)
      expect(result.service).to eq(ChangelogGenerator::Service::ManagedPostgreSQL)
      expect(result.reasoning).to include('firewall')
    end

    it 'categorizes internal PRs correctly' do
      result = categorizer.call(pull_request: internal_pr)
      
      expect(result.category).to eq(ChangelogGenerator::PRCategory::InternalImprovement)
      expect(result.reasoning).to include('internal')
    end

    it 'defaults to Other service when unclear' do
      unclear_pr = ChangelogGenerator::PullRequest.new(
        pr: 9999,
        title: "Update documentation",
        description: "Updates some docs",
        ellipsis_summary: ""
      )
      
      result = categorizer.call(pull_request: unclear_pr)
      expect(result.service).to eq(ChangelogGenerator::Service::Other)
    end
  end

  describe ChangelogGenerator::TitleGeneratorModule, :vcr do
    let(:generator) { described_class.new }
    let(:pr_group) { [sample_pr] }

    it 'generates user-friendly titles' do
      result = generator.call(pr_group: pr_group)
      
      expect(result.feature_title).to be_a(String)
      expect(result.feature_title).not_to include('functionality') # Avoid technical jargon
      expect(result.title_rationale).to be_a(String)
    end
  end

  describe ChangelogGenerator::ModularChangelogGenerator do
    let(:generator) { described_class.new }
    let(:pull_requests) { [sample_pr, internal_pr] }

    it 'orchestrates the complete pipeline', :vcr do
      result = generator.call(
        pull_requests: pull_requests,
        month: 'May',
        year: 2025
      )
      
      expect(result.mdx_content).to include('---')
      expect(result.mdx_content).to include('title: "May 2025"')
      expect(result.mdx_content).to include('import { PrList }')
      expect(result.mdx_content).to include('PostgreSQL')
      expect(result.mdx_content).not_to include('3001') # Internal PR should be filtered
    end

    it 'groups related PRs together', :vcr do
      related_pr = ChangelogGenerator::PullRequest.new(
        pr: 3367,
        title: "Fix PostgreSQL firewall rule validation",
        description: "Fixes validation issues with firewall rules",
        ellipsis_summary: "Fixes firewall rule validation"
      )
      
      result = generator.call(
        pull_requests: [sample_pr, related_pr],
        month: 'May',
        year: 2025
      )
      
      # Should group both PostgreSQL firewall PRs together
      expect(result.mdx_content).to match(/<PrList ids=\{.*3366.*3367.*\}/)
    end
  end

  describe 'Monolithic vs Modular comparison' do
    let(:monolithic) { ChangelogGenerator::MonolithicModule.new }
    let(:modular) { ChangelogGenerator::ModularChangelogGenerator.new }
    let(:test_prs) { [sample_pr] }

    it 'produces similar outputs', :vcr do
      monolithic_result = monolithic.call(
        pull_requests: test_prs,
        month: 'May',
        year: 2025
      )
      
      modular_result = modular.call(
        pull_requests: test_prs,
        month: 'May',
        year: 2025
      )
      
      # Both should produce valid MDX
      expect(monolithic_result.mdx_content).to include('---')
      expect(modular_result.mdx_content).to include('---')
      
      # Both should include the PR
      expect(monolithic_result.mdx_content).to include('3366')
      expect(modular_result.mdx_content).to include('3366')
    end
  end
end