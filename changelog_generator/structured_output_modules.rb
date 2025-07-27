# frozen_string_literal: true

require 'dspy'
require 'ostruct'
require_relative 'signatures'
require_relative 'structured_output_signatures'
require_relative 'mdx_renderer'

module ChangelogGenerator
  module StructuredOutput
    # Structured Output implementation of BatchPRAnalyzer
    class BatchPRAnalyzerModule < DSPy::Module
      def initialize
        super()
        # Use ChainOfThought for complex reasoning
        @predictor = DSPy::ChainOfThought.new(BatchPRAnalyzerSignature)
      end

      def forward(pr_batch:)
        result = @predictor.forward(pr_batch: pr_batch)
        
        # Convert to expected format
        themes = result.analysis.themes.map do |theme_data|
          Batch::Theme.new(
            name: theme_data.name,
            description: theme_data.description,
            subthemes: [],
            pr_ids: theme_data.pr_ids
          )
        end
        
        OpenStruct.new(
          themes: themes,
          pr_theme_mapping: result.analysis.pr_theme_mapping
        )
      end

      def call(pr_batch:)
        forward(pr_batch: pr_batch)
      end
    end

    # Structured Output implementation of ThemeAccumulator
    class ThemeAccumulatorModule < DSPy::Module
      def initialize
        super()
        # Use ChainOfThought for theme merging
        @predictor = DSPy::ChainOfThought.new(ThemeAccumulatorSignature)
      end

      def forward(existing_themes:, new_themes:)
        # Convert to ThemeData format
        existing_data = existing_themes.map do |theme|
          ThemeData.new(
            name: theme.name,
            description: theme.description,
            pr_ids: theme.pr_ids
          )
        end
        
        new_data = new_themes.map do |theme|
          ThemeData.new(
            name: theme.name,
            description: theme.description,
            pr_ids: theme.pr_ids
          )
        end
        
        result = @predictor.forward(
          existing_themes: existing_data,
          new_themes: new_data
        )
        
        # Convert back to Theme objects
        merged_themes = result.result.merged_themes.map do |theme_data|
          Batch::Theme.new(
            name: theme_data.name,
            description: theme_data.description,
            subthemes: [],
            pr_ids: theme_data.pr_ids
          )
        end
        
        OpenStruct.new(merged_themes: merged_themes)
      end

      def call(existing_themes:, new_themes:)
        forward(existing_themes: existing_themes, new_themes: new_themes)
      end
    end

    # Structured Output implementation of SubthemeGenerator
    class SubthemeGeneratorModule < DSPy::Module
      def initialize
        super()
        # Use Predict for structured output
        @predictor = DSPy::Predict.new(SubthemeGeneratorSignature)
      end

      def forward(theme:, prs:)
        # Convert theme to ThemeData
        theme_data = ThemeData.new(
          name: theme.name,
          description: theme.description,
          pr_ids: theme.pr_ids
        )
        
        result = @predictor.forward(theme: theme_data, prs: prs)
        
        # Convert to Subtheme objects
        subthemes = result.result.subthemes.map do |subtheme_data|
          Batch::Subtheme.new(
            title: subtheme_data.title,
            description: subtheme_data.description,
            pr_ids: subtheme_data.pr_ids
          )
        end
        
        OpenStruct.new(subthemes: subthemes)
      end

      def call(theme:, prs:)
        forward(theme: theme, prs: prs)
      end
    end

    # Structured Output implementation of ThemeDescriptionWriter
    class ThemeDescriptionWriterModule < DSPy::Module
      def initialize
        super()
        # Use Predict for structured output
        @predictor = DSPy::Predict.new(ThemeDescriptionWriterSignature)
      end

      def forward(theme:, prs:)
        # Convert theme to ThemeData
        theme_data = ThemeData.new(
          name: theme.name,
          description: theme.description,
          pr_ids: theme.pr_ids
        )
        
        result = @predictor.forward(theme: theme_data, prs: prs)
        
        OpenStruct.new(theme_description: result.result.description)
      end

      def call(theme:, prs:)
        forward(theme: theme, prs: prs)
      end
    end

    # Structured Output implementation of BatchChangelogGenerator
    class BatchChangelogGenerator
      def initialize
        @batch_analyzer = BatchPRAnalyzerModule.new
        @theme_accumulator = ThemeAccumulatorModule.new
        @subtheme_generator = SubthemeGeneratorModule.new
        @description_writer = ThemeDescriptionWriterModule.new
        @mdx_renderer = Batch::MDXRenderer.new
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
          Batch::Theme.new(
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