# frozen_string_literal: true

require 'erb'
require 'ostruct'

module ChangelogGenerator
  module Batch
    class MDXRenderer
      def initialize(template_path: File.join(__dir__, 'templates/changelog.mdx.erb'))
        @template = ERB.new(File.read(template_path))
      end

      def render(themes:, month:, year:)
        binding_context = OpenStruct.new(
          themes: themes,
          month: month,
          year: year
        ).instance_eval { binding }
        
        @template.result(binding_context)
      end
    end
  end
end