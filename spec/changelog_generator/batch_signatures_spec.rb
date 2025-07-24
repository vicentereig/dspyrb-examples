# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ChangelogGenerator::Batch' do
  describe 'Data Structures' do
    describe 'Subtheme' do
      it 'creates a Subtheme with required fields' do
        subtheme = ChangelogGenerator::Batch::Subtheme.new(
          title: 'Built-in Metrics',
          description: 'Track CPU, memory, and disk usage directly from the dashboard',
          pr_ids: [3170, 3202]
        )

        expect(subtheme.title).to eq('Built-in Metrics')
        expect(subtheme.description).to eq('Track CPU, memory, and disk usage directly from the dashboard')
        expect(subtheme.pr_ids).to eq([3170, 3202])
      end

      it 'requires all fields' do
        expect {
          ChangelogGenerator::Batch::Subtheme.new(
            title: 'Built-in Metrics',
            description: 'Track metrics'
            # Missing pr_ids
          )
        }.to raise_error(ArgumentError)
      end
    end

    describe 'Theme' do
      it 'creates a Theme with required fields' do
        subtheme1 = ChangelogGenerator::Batch::Subtheme.new(
          title: 'Built-in Metrics',
          description: 'Track CPU, memory, and disk usage',
          pr_ids: [3170, 3202]
        )
        
        subtheme2 = ChangelogGenerator::Batch::Subtheme.new(
          title: 'Firewall Rule Enhancements',
          description: 'Improved security controls',
          pr_ids: [3248, 3274]
        )

        theme = ChangelogGenerator::Batch::Theme.new(
          name: 'Managed PostgreSQL',
          description: 'Comprehensive database management improvements',
          subthemes: [subtheme1, subtheme2],
          pr_ids: [3170, 3202, 3248, 3274]
        )

        expect(theme.name).to eq('Managed PostgreSQL')
        expect(theme.description).to eq('Comprehensive database management improvements')
        expect(theme.subthemes.size).to eq(2)
        expect(theme.pr_ids).to eq([3170, 3202, 3248, 3274])
      end

      it 'validates subthemes are of correct type' do
        expect {
          ChangelogGenerator::Batch::Theme.new(
            name: 'Invalid Theme',
            description: 'This should fail',
            subthemes: ['not a subtheme object'],
            pr_ids: [123]
          )
        }.to raise_error(TypeError)
      end

      it 'can have empty subthemes array' do
        theme = ChangelogGenerator::Batch::Theme.new(
          name: 'Simple Theme',
          description: 'A theme without subthemes',
          subthemes: [],
          pr_ids: [456]
        )

        expect(theme.subthemes).to be_empty
      end
    end
  end

  describe 'DSPy Signatures' do
    describe 'BatchPRAnalyzer' do
      it 'is a valid DSPy signature' do
        expect(ChangelogGenerator::Batch::BatchPRAnalyzer).to be < DSPy::Signature
      end

      it 'has a meaningful description' do
        expect(ChangelogGenerator::Batch::BatchPRAnalyzer.description).to include('batch')
        expect(ChangelogGenerator::Batch::BatchPRAnalyzer.description).to include('themes')
      end

      it 'can be instantiated' do
        signature = ChangelogGenerator::Batch::BatchPRAnalyzer.new
        expect(signature).to be_a(ChangelogGenerator::Batch::BatchPRAnalyzer)
      end
    end

    describe 'ThemeAccumulator' do
      it 'is a valid DSPy signature' do
        expect(ChangelogGenerator::Batch::ThemeAccumulator).to be < DSPy::Signature
      end

      it 'has a meaningful description' do
        expect(ChangelogGenerator::Batch::ThemeAccumulator.description).to include('Merge')
        expect(ChangelogGenerator::Batch::ThemeAccumulator.description).to include('themes')
      end

      it 'can be instantiated' do
        signature = ChangelogGenerator::Batch::ThemeAccumulator.new
        expect(signature).to be_a(ChangelogGenerator::Batch::ThemeAccumulator)
      end
    end
  end
end