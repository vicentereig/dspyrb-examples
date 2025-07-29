# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

module ChangelogGenerator
  # Data structures using T::Struct
  class PullRequest < T::Struct
    const :pr, Integer
    const :title, String
    const :description, String
    const :ellipsis_summary, String
  end

  class PRCategory < T::Enum
    enums do
      CustomerFacingAvailable = new('customer_facing_available')
      CustomerFacingNotReleased = new('customer_facing_not_released')
      BugFixMaintenance = new('bug_fix_maintenance')
      InternalImprovement = new('internal_improvement')
    end
  end

  class Service < T::Enum
    enums do
      ManagedPostgreSQL = new('Managed PostgreSQL')
      GitHubRunners = new('GitHub Runners')
      UbicloudKubernetes = new('Ubicloud Kubernetes')
      AIAndGPUs = new('AI & GPUs')
      Compute = new('Compute')
      LoadBalancers = new('Load Balancers')
      PlatformImprovements = new('Platform Improvements')
      DeveloperExperience = new('Developer Experience')
      Other = new('Other')
    end
  end

  class CategorizedPR < T::Struct
    const :pull_request, PullRequest
    const :category, PRCategory
    const :service, Service  # Always required - use Service::Other if unclear
    const :reasoning, String
  end

  class Feature < T::Struct
    const :title, String
    const :description, String
    const :pr_ids, T::Array[Integer]
    const :image_path, T.nilable(String)
  end

  class ServiceChangelog < T::Struct
    const :service, Service
    const :features, T::Array[Feature]
  end

  # DSPy Signatures
  class PRCategorizer < DSPy::Signature
    description "Categorize a pull request based on its content and determine if it's customer-facing."

    input do
      const :pull_request, PullRequest, description: "Pull request with title, description, and summary"
    end
    
    output do
      const :category, PRCategory, description: "Category of the PR (customer-facing available, not released, bug fix, internal)"
      const :service, Service, description: "Service this PR belongs to"
    end
  end

  class FeatureGrouper < DSPy::Signature
    description "Group related pull requests into cohesive features for the changelog."

    input do
      const :categorized_prs, T::Array[CategorizedPR], 
            description: "List of categorized PRs for a single service"
    end
    
    output do
      const :grouped_features, T::Array[T::Array[Integer]], 
            description: "Arrays of PR IDs that should be grouped together"
      const :grouping_rationale, T::Array[String],
            description: "Explanation for each grouping"
    end
  end

  class TitleGenerator < DSPy::Signature
    description "Generate user-friendly feature titles from technical PR titles."

    input do
      const :pr_group, T::Array[PullRequest], 
            description: "Group of related PRs"
    end
    
    output do
      const :feature_title, String, 
            description: "Clear, benefit-focused title for the feature"
      const :title_rationale, String,
            description: "Explanation of title choice"
    end
  end

  class DescriptionWriter < DSPy::Signature
    description "Write engaging, customer-focused descriptions for features."

    input do
      const :pr_group, T::Array[PullRequest], 
            description: "Group of related PRs"
      const :feature_title, String, 
            description: "User-friendly title for the feature"
      const :service, Service,
            description: "Service this feature belongs to"
    end
    
    output do
      const :description, String, 
            description: "Engaging description focusing on customer benefits and usage"
      const :suggested_image_name, T.nilable(String),
            description: "Suggested image filename if screenshot would be helpful"
    end
  end

  class MDXFormatter < DSPy::Signature
    description "Format the changelog entries into proper MDX format."

    input do
      const :service_changelogs, T::Array[ServiceChangelog], 
            description: "All service changelogs with features"
      const :month, String, 
            description: "Month of the changelog (e.g., 'May')"
      const :year, Integer, 
            description: "Year of the changelog (e.g., 2025)"
    end
    
    output do
      const :mdx_content, String, 
            description: "Complete MDX-formatted changelog"
    end
  end

  # Alternative: Single-step changelog generation for comparison
  class ChangelogGenerator < DSPy::Signature
    description "Generate a complete changelog from pull requests in one step (mimics original approach)."

    input do
      const :pull_requests, T::Array[PullRequest],
            description: "All pull requests for the month"
      const :month, String,
            description: "Month of the changelog"
      const :year, Integer,
            description: "Year of the changelog"
    end
    
    output do
      const :mdx_content, String,
            description: "Complete MDX-formatted changelog"
    end
  end
end