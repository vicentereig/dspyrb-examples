# frozen_string_literal: true

require 'dspy'
require 'ostruct'
require 'json'
require_relative 'batch_signatures'
require_relative 'mdx_renderer'

module ChangelogGenerator
  module Batch
    # Uses ChainOfThought for complex reasoning about themes across multiple PRs
    class BatchPRAnalyzerModule < DSPy::ChainOfThought
      def initialize
        super(BatchPRAnalyzer)
      end

      def call(pr_batch:)
        result = super(pr_batch: pr_batch)
        
        # Convert the raw output to Theme objects
        themes = result.theme_names.zip(result.theme_descriptions, result.theme_pr_ids).map do |name, desc, pr_ids|
          Theme.new(
            name: name || "",
            description: desc || "",
            subthemes: [],  # Will be populated later
            pr_ids: pr_ids || []
          )
        end
        
        # Convert string keys to integer keys in pr_theme_mapping
        pr_theme_mapping = result.pr_theme_mapping.transform_keys(&:to_i)
        
        OpenStruct.new(
          themes: themes,
          pr_theme_mapping: pr_theme_mapping
        )
      end
    end

    # Uses ChainOfThought to reason about theme similarity and merging
    class ThemeAccumulatorModule < DSPy::ChainOfThought
      def initialize
        super(ThemeAccumulator)
      end

      def call(existing_themes:, new_themes:)
        # Convert Theme objects to arrays for the signature
        existing_names = existing_themes.map(&:name)
        existing_descriptions = existing_themes.map(&:description)
        existing_pr_ids = existing_themes.map(&:pr_ids)
        
        new_names = new_themes.map(&:name)
        new_descriptions = new_themes.map(&:description)
        new_pr_ids = new_themes.map(&:pr_ids)
        
        result = super(
          existing_theme_names: existing_names,
          existing_theme_descriptions: existing_descriptions,
          existing_theme_pr_ids: existing_pr_ids,
          new_theme_names: new_names,
          new_theme_descriptions: new_descriptions,
          new_theme_pr_ids: new_pr_ids
        )
        
        # Convert back to Theme objects
        merged_themes = result.merged_theme_names.zip(
          result.merged_theme_descriptions,
          result.merged_theme_pr_ids
        ).map do |name, desc, pr_ids|
          Theme.new(
            name: name || "",
            description: desc || "",
            subthemes: [],  # Will be populated later
            pr_ids: pr_ids || []
          )
        end
        
        OpenStruct.new(merged_themes: merged_themes)
      end
    end

    # Uses Predict for generating subthemes from a theme
    class SubthemeGeneratorModule < DSPy::Predict
      def initialize
        super(SubthemeGenerator)
      end

      def call(theme:, prs:)
        # Convert to simpler format for the signature
        pr_titles = prs.map(&:title)
        pr_descriptions = prs.map(&:description)
        
        result = super(
          theme_name: theme.name,
          theme_pr_ids: theme.pr_ids,
          pr_titles: pr_titles,
          pr_descriptions: pr_descriptions
        )
        
        # Convert back to Subtheme objects
        subthemes = result.subtheme_titles.zip(
          result.subtheme_descriptions,
          result.subtheme_pr_ids
        ).map do |title, desc, pr_ids|
          Subtheme.new(
            title: title,
            description: desc,
            pr_ids: pr_ids
          )
        end
        
        OpenStruct.new(subthemes: subthemes)
      end
    end

    # Uses Predict for writing theme descriptions
    class ThemeDescriptionWriterModule < DSPy::Predict
      def initialize
        super(ThemeDescriptionWriter)
      end

      def call(theme:, prs:)
        result = super(
          theme_name: theme.name,
          pr_titles: prs.map(&:title),
          pr_descriptions: prs.map(&:description)
        )
        
        OpenStruct.new(theme_description: result.theme_description)
      end
    end

    # Uses Predict for MDX formatting
    class BatchMDXFormatterModule < DSPy::Predict
      def initialize
        super(BatchMDXFormatter)
      end

      def call(themes:, month:, year:)
        # Convert themes to simpler format
        theme_names = themes.map(&:name)
        theme_descriptions = themes.map(&:description)
        theme_pr_ids = themes.map(&:pr_ids)
        
        # Encode subtheme data as JSON strings
        theme_subtheme_data = themes.map do |theme|
          subtheme_data = theme.subthemes.map do |st|
            {
              title: st.title,
              description: st.description,
              pr_ids: st.pr_ids
            }
          end
          JSON.generate(subtheme_data)
        end
        
        result = super(
          theme_names: theme_names,
          theme_descriptions: theme_descriptions,
          theme_subtheme_data: theme_subtheme_data,
          theme_pr_ids: theme_pr_ids,
          month: month,
          year: year
        )
        
        OpenStruct.new(mdx_content: result.mdx_content)
      end
    end

    # Main orchestrator for batch changelog generation
    class BatchChangelogGenerator
      def initialize
        @batch_analyzer = BatchPRAnalyzerModule.new
        @theme_accumulator = ThemeAccumulatorModule.new
        @subtheme_generator = SubthemeGeneratorModule.new
        @description_writer = ThemeDescriptionWriterModule.new
        @mdx_renderer = MDXRenderer.new
      end

      def call(pull_requests:, month:, year:, batch_size: 20)
        # Process PRs in batches to identify themes
        all_themes = []
        
        pull_requests.each_slice(batch_size) do |pr_batch|
          # Analyze batch to find themes
          batch_result = @batch_analyzer.call(pr_batch: pr_batch)
          
          # Accumulate themes across batches
          if all_themes.empty?
            all_themes = batch_result.themes
          else
            accumulation_result = @theme_accumulator.call(
              existing_themes: all_themes,
              new_themes: batch_result.themes
            )
            all_themes = accumulation_result.merged_themes
          end
        end

        # Process each theme to add subthemes and descriptions
        processed_themes = all_themes.map do |theme|
          # Get PRs for this theme
          theme_prs = pull_requests.select { |pr| theme.pr_ids.include?(pr.pr) }
          
          # Generate subthemes
          subtheme_result = @subtheme_generator.call(
            theme: theme,
            prs: theme_prs
          )
          
          # Generate improved description
          desc_result = @description_writer.call(
            theme: theme,
            prs: theme_prs
          )
          
          # Create updated theme with subthemes and description
          Theme.new(
            name: theme.name,
            description: desc_result.theme_description,
            subthemes: subtheme_result.subthemes,
            pr_ids: theme.pr_ids
          )
        end

        # Format as MDX using ERB template
        mdx_content = @mdx_renderer.render(
          themes: processed_themes,
          month: month,
          year: year
        )
        
        OpenStruct.new(mdx_content: mdx_content)
      end
    end
  end
end