# frozen_string_literal: true

RSpec.describe 'ChangelogGenerator Signatures' do
  describe ChangelogGenerator::PullRequest do
    it 'creates a valid PR struct' do
      pr = described_class.new(
        pr: 123,
        title: 'Add new feature',
        description: 'This adds a new feature',
        ellipsis_summary: 'Adds new feature functionality'
      )
      
      expect(pr.pr).to eq(123)
      expect(pr.title).to eq('Add new feature')
      expect(pr.description).to eq('This adds a new feature')
      expect(pr.ellipsis_summary).to eq('Adds new feature functionality')
    end
  end

  describe ChangelogGenerator::PRCategory do
    it 'has all expected categories' do
      expect(described_class.values).to contain_exactly(
        described_class::CustomerFacingAvailable,
        described_class::CustomerFacingNotReleased,
        described_class::BugFixMaintenance,
        described_class::InternalImprovement
      )
    end

    it 'serializes to expected strings' do
      expect(described_class::CustomerFacingAvailable.serialize).to eq('customer_facing_available')
      expect(described_class::CustomerFacingNotReleased.serialize).to eq('customer_facing_not_released')
    end
  end

  describe ChangelogGenerator::Service do
    it 'has all expected services' do
      services = described_class.values.map(&:serialize)
      expect(services).to include(
        'Managed PostgreSQL',
        'GitHub Runners',
        'Ubicloud Kubernetes',
        'AI & GPUs',
        'Compute',
        'Other'
      )
    end

    it 'includes Other as a fallback' do
      expect(described_class::Other).to be_a(described_class)
      expect(described_class::Other.serialize).to eq('Other')
    end
  end

  describe ChangelogGenerator::PRCategorizer do
    it 'has correct input and output fields' do
      # Check input field descriptors
      input_descriptors = described_class.input_field_descriptors
      expect(input_descriptors[:pull_request].type).to eq(ChangelogGenerator::PullRequest)
      
      # Check output field descriptors
      output_descriptors = described_class.output_field_descriptors
      expect(output_descriptors[:category].type).to eq(ChangelogGenerator::PRCategory)
      expect(output_descriptors[:service].type).to eq(ChangelogGenerator::Service)
      expect(output_descriptors[:service].default_value).to be_nil
    end
  end

  describe ChangelogGenerator::FeatureGrouper do
    it 'accepts arrays of categorized PRs' do
      # Check via struct props
      input_props = described_class.input_struct_class.props
      output_props = described_class.output_struct_class.props
      
      expect(input_props[:categorized_prs][:type]).to eq(T::Array[ChangelogGenerator::CategorizedPR])
      expect(output_props[:grouped_features][:type]).to eq(T::Array[T::Array[Integer]])
    end
  end

  describe ChangelogGenerator::MDXFormatter do
    it 'outputs MDX content as a string' do
      # Check via struct props
      input_props = described_class.input_struct_class.props
      output_props = described_class.output_struct_class.props
      
      expect(output_props[:mdx_content][:type]).to eq(String)
      expect(input_props[:month][:type]).to eq(String)
      expect(input_props[:year][:type]).to eq(Integer)
    end
  end
end