# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'
require_relative 'signatures'

module ChangelogGenerator
  module Batch
    # Data structures for batch processing
    class Subtheme < T::Struct
      const :title, String
      const :description, String
      const :pr_ids, T::Array[Integer]
    end

    class Theme < T::Struct
      const :name, String
      const :description, String
      const :subthemes, T::Array[Subtheme]
      const :pr_ids, T::Array[Integer]
    end

    # DSPy Signatures for batch processing
    class BatchPRAnalyzer < DSPy::Signature
      description "Analyze a batch of pull requests to identify themes and relationships."

      input do
        const :pr_batch, T::Array[PullRequest], 
              description: "Batch of pull requests to analyze together"
      end
      
      output do
        const :theme_names, T::Array[String], 
              description: "Names of themes discovered from the PR batch"
        const :theme_descriptions, T::Array[String],
              description: "Descriptions for each theme"
        const :theme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs belonging to each theme"
        const :pr_theme_mapping, T::Hash[String, String],
              description: "Mapping of PR ID (as string) to theme name"
      end
    end

    class ThemeAccumulator < DSPy::Signature
      description "Merge themes across batches, consolidating similar themes and maintaining coherence."

      input do
        const :existing_theme_names, T::Array[String],
              description: "Names of themes from previous batches"
        const :existing_theme_descriptions, T::Array[String],
              description: "Descriptions of themes from previous batches"
        const :existing_theme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs for each existing theme"
        const :new_theme_names, T::Array[String],
              description: "Names of themes from current batch"
        const :new_theme_descriptions, T::Array[String],
              description: "Descriptions of themes from current batch"
        const :new_theme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs for each new theme"
      end
      
      output do
        const :merged_theme_names, T::Array[String],
              description: "Names of consolidated themes"
        const :merged_theme_descriptions, T::Array[String],
              description: "Descriptions of consolidated themes"
        const :merged_theme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs for each consolidated theme"
      end
    end

    class SubthemeGenerator < DSPy::Signature
      description "Generate subthemes for a given theme based on its PRs."

      input do
        const :theme_name, String,
              description: "Name of the theme to generate subthemes for"
        const :theme_pr_ids, T::Array[Integer],
              description: "PR IDs belonging to this theme"
        const :pr_titles, T::Array[String],
              description: "Titles of PRs in this theme"
        const :pr_descriptions, T::Array[String],
              description: "Descriptions of PRs in this theme"
      end
      
      output do
        const :subtheme_titles, T::Array[String],
              description: "Titles for each subtheme"
        const :subtheme_descriptions, T::Array[String],
              description: "Descriptions for each subtheme"
        const :subtheme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs belonging to each subtheme"
      end
    end

    class ThemeDescriptionWriter < DSPy::Signature
      description "Write customer-focused descriptions for themes and their benefits."

      input do
        const :theme_name, String,
              description: "Name of the theme"
        const :pr_titles, T::Array[String],
              description: "Titles of PRs in this theme"
        const :pr_descriptions, T::Array[String],
              description: "Descriptions of PRs for context"
      end
      
      output do
        const :theme_description, String,
              description: "Engaging description of the theme's impact and benefits"
      end
    end

    class BatchMDXFormatter < DSPy::Signature
      description "Format themes into MDX changelog format."

      input do
        const :theme_names, T::Array[String],
              description: "Names of all themes"
        const :theme_descriptions, T::Array[String],
              description: "Descriptions of all themes"
        const :theme_subtheme_data, T::Array[String],
              description: "JSON-encoded subtheme data for each theme"
        const :theme_pr_ids, T::Array[T::Array[Integer]],
              description: "PR IDs for each theme"
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
end