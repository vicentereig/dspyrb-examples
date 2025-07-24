# frozen_string_literal: true

require 'dspy'
require_relative 'signatures'

module ChangelogGenerator
  # For the modular approach, we'll use ChainOfThought for complex reasoning tasks
  # and regular Predict for simpler transformations
  
  class PRCategorizerModule < DSPy::ChainOfThought
    # Uses ChainOfThought because categorization requires reasoning about:
    # - Whether a feature is customer-facing
    # - Whether it's already released
    # - Which service it belongs to
    def initialize
      super(PRCategorizer)
    end
  end

  class FeatureGrouperModule < DSPy::ChainOfThought
    # Uses ChainOfThought because grouping requires reasoning about:
    # - Which PRs are related
    # - How they form a cohesive feature
    def initialize
      super(FeatureGrouper)
    end
  end

  class TitleGeneratorModule < DSPy::Predict
    # Uses Predict because it's a straightforward transformation
    # from technical titles to user-friendly ones
    def initialize
      super(TitleGenerator)
    end
  end

  class DescriptionWriterModule < DSPy::Predict
    # Uses Predict for generating descriptions
    # The signature provides enough context
    def initialize
      super(DescriptionWriter)
    end
  end

  class MDXFormatterModule < DSPy::Predict
    # Uses Predict for formatting - it's mostly templating
    def initialize
      super(MDXFormatter)
    end
  end

  # For comparison: Monolithic approach that does everything in one go
  class MonolithicModule < DSPy::Predict
    # Uses Predict to mimic the original approach
    # where a single prompt handles everything
    def initialize
      super(ChangelogGenerator)
    end
  end

  # Main orchestrator that chains the modules together
  class ModularChangelogGenerator
    def initialize
      @categorizer = PRCategorizerModule.new
      @grouper = FeatureGrouperModule.new
      @title_generator = TitleGeneratorModule.new
      @description_writer = DescriptionWriterModule.new
      @formatter = MDXFormatterModule.new
    end

    def call(pull_requests:, month:, year:)
      # Step 1: Categorize all PRs
      categorized_prs = pull_requests.map do |pr|
        result = @categorizer.call(pull_request: pr)
        CategorizedPR.new(
          pull_request: pr,
          category: result.category,
          service: result.service.is_a?(String) ? Service.deserialize(result.service) : result.service,
          reasoning: result.reasoning || ""  # ChainOfThought provides this
        )
      end

      # Step 2: Filter only customer-facing available PRs
      customer_facing_prs = categorized_prs.select do |cpr|
        cpr.category == PRCategory::CustomerFacingAvailable
      end

      # Step 3: Group by service (service is always non-nil now)
      prs_by_service = customer_facing_prs.group_by(&:service)

      # Step 4: Process each service
      service_changelogs = prs_by_service.map do |service, service_prs|
        # Group related PRs
        grouping_result = @grouper.call(categorized_prs: service_prs)
        
        # Generate features for each group
        features = grouping_result.grouped_features.map do |pr_ids|
          # Get the PRs for this group
          group_prs = service_prs
            .select { |cpr| pr_ids.include?(cpr.pull_request.pr) }
            .map(&:pull_request)
          
          # Generate title
          title_result = @title_generator.call(pr_group: group_prs)
          
          # Generate description
          desc_result = @description_writer.call(
            pr_group: group_prs,
            feature_title: title_result.feature_title,
            service: service
          )
          
          Feature.new(
            title: title_result.feature_title,
            description: desc_result.description,
            pr_ids: pr_ids,
            image_path: desc_result.suggested_image_name
          )
        end

        ServiceChangelog.new(service: service, features: features)
      end

      # Step 5: Format as MDX
      @formatter.call(
        service_changelogs: service_changelogs,
        month: month,
        year: year
      )
    end
  end
end