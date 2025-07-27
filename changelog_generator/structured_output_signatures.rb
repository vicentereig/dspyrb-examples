# frozen_string_literal: true

require 'dspy'
require 'sorbet-runtime'

module ChangelogGenerator
  module StructuredOutput
    # T::Struct schemas for DSPy.rb structured outputs

    # Theme structure for structured outputs
    class ThemeData < T::Struct
      const :name, String
      const :description, String
      const :pr_ids, T::Array[Integer]
    end

    # Subtheme structure for structured outputs
    class SubthemeData < T::Struct
      const :title, String
      const :description, String
      const :pr_ids, T::Array[Integer]
    end

    # Complete theme with subthemes
    class CompleteTheme < T::Struct
      const :name, String
      const :description, String
      const :pr_ids, T::Array[Integer]
      const :subthemes, T::Array[SubthemeData]
    end

    # Batch PR Analysis Output
    class BatchPRAnalysisOutput < T::Struct
      const :themes, T::Array[ThemeData]
      const :pr_theme_mapping, T::Hash[Integer, String]
    end

    # Theme Accumulation Output
    class ThemeAccumulationOutput < T::Struct
      const :merged_themes, T::Array[ThemeData]
      const :merge_decisions, T::Array[T::Hash[Symbol, T.untyped]]
    end

    # Subtheme Generation Output
    class SubthemeGenerationOutput < T::Struct
      const :subthemes, T::Array[SubthemeData]
    end

    # Theme Description Output
    class ThemeDescriptionOutput < T::Struct
      const :description, String
      const :key_benefits, T::Array[String]
    end

    # MDX Formatting Output
    class MDXFormattingOutput < T::Struct
      const :mdx_content, String
      const :metadata, T::Hash[Symbol, T.untyped]
    end

    # Structured Output Signatures

    class BatchPRAnalyzerSignature < DSPy::Signature
      description "Analyze a batch of pull requests to identify themes using structured output"

      input do
        const :pr_batch, T::Array[PullRequest],
              description: "Batch of pull requests to analyze"
      end

      output do
        const :analysis, BatchPRAnalysisOutput,
              description: "Structured analysis with themes and PR mappings"
      end
    end

    class ThemeAccumulatorSignature < DSPy::Signature
      description "Merge themes across batches using structured output"

      input do
        const :existing_themes, T::Array[ThemeData],
              description: "Themes from previous batches"
        const :new_themes, T::Array[ThemeData],
              description: "Themes from current batch"
      end

      output do
        const :result, ThemeAccumulationOutput,
              description: "Merged themes with decision rationale"
      end
    end

    class SubthemeGeneratorSignature < DSPy::Signature
      description "Generate subthemes for a theme using structured output"

      input do
        const :theme, ThemeData,
              description: "Theme to generate subthemes for"
        const :prs, T::Array[PullRequest],
              description: "Pull requests belonging to this theme"
      end

      output do
        const :result, SubthemeGenerationOutput,
              description: "Generated subthemes with PR associations"
      end
    end

    class ThemeDescriptionWriterSignature < DSPy::Signature
      description "Write customer-focused theme descriptions using structured output"

      input do
        const :theme, ThemeData,
              description: "Theme to describe"
        const :prs, T::Array[PullRequest],
              description: "Pull requests for context"
      end

      output do
        const :result, ThemeDescriptionOutput,
              description: "Enhanced description with key benefits"
      end
    end

    class MDXFormatterSignature < DSPy::Signature
      description "Format themes into MDX changelog using structured output"

      input do
        const :themes, T::Array[CompleteTheme],
              description: "Complete themes with subthemes"
        const :month, String,
              description: "Month of the changelog"
        const :year, Integer,
              description: "Year of the changelog"
      end

      output do
        const :result, MDXFormattingOutput,
              description: "Formatted MDX content with metadata"
      end
    end
  end
end