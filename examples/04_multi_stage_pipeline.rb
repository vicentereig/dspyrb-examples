#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 4: Multi-stage Pipeline
# This demonstrates composing multiple LLM calls into complex workflows

require_relative '../setup'

# Signatures for article writing pipeline
class ArticleOutline < DSPy::Signature
  description "Create an outline for an article on a given topic"
  
  input do
    const :topic, String
    const :target_audience, String
  end
  
  output do
    const :title, String
    const :sections, T::Array[String]
    const :estimated_word_count, Integer
  end
end

class SectionWriter < DSPy::Signature
  description "Write a section of an article"
  
  input do
    const :topic, String
    const :title, String
    const :section_heading, String
    const :target_audience, String
  end
  
  output do
    const :content, String
  end
end

class ArticleReviewer < DSPy::Signature
  description "Review and provide feedback on article content"
  
  input do
    const :title, String
    const :content, String
    const :target_audience, String
  end
  
  output do
    const :overall_rating, Float
    const :strengths, T::Array[String]
    const :improvements, T::Array[String]
    const :revised_content, String
  end
end

# Pipeline Module
class ArticleWritingPipeline < DSPy::Module
  def initialize
    @outline_generator = DSPy::ChainOfThought.new(ArticleOutline)
    @section_writer = DSPy::ChainOfThought.new(SectionWriter)
    @article_reviewer = DSPy::ChainOfThought.new(ArticleReviewer)
  end
  
  def forward(topic:, target_audience: "general audience")
    puts "📋 Generating outline..."
    outline = @outline_generator.call(topic: topic, target_audience: target_audience)
    
    puts "📝 Writing sections..."
    sections_content = outline.sections.map.with_index do |section, i|
      puts "   Writing section #{i+1}: #{section}"
      result = @section_writer.call(
        topic: topic,
        title: outline.title,
        section_heading: section,
        target_audience: target_audience
      )
      {
        heading: section,
        content: result.content
      }
    end
    
    # Combine all content
    full_content = sections_content.map { |s| "## #{s[:heading]}\n\n#{s[:content]}" }.join("\n\n")
    
    puts "🔍 Reviewing article..."
    review = @article_reviewer.call(
      title: outline.title,
      content: full_content,
      target_audience: target_audience
    )
    
    {
      title: outline.title,
      outline: outline,
      sections: sections_content,
      full_content: full_content,
      review: review,
      final_content: review.revised_content
    }
  end
end

def run_multi_stage_pipeline_example
  puts "📰 Multi-stage Article Writing Pipeline Example"
  puts "=" * 60
  
  pipeline = ArticleWritingPipeline.new
  
  topics = [
    {
      topic: "The Future of Remote Work",
      audience: "business professionals"
    },
    {
      topic: "Introduction to Machine Learning",
      audience: "beginners with no technical background"
    }
  ]
  
  topics.each_with_index do |topic_info, i|
    puts "\n#{i+1}. Processing topic: '#{topic_info[:topic]}'"
    puts "   Target audience: #{topic_info[:audience]}"
    puts "   " + "-" * 50
    
    begin
      result = pipeline.forward(
        topic: topic_info[:topic],
        target_audience: topic_info[:audience]
      )
      
      puts "\n📄 Article Results:"
      puts "   Title: #{result[:title]}"
      puts "   Sections: #{result[:outline].sections.length}"
      puts "   Estimated words: #{result[:outline].estimated_word_count}"
      puts "   Review rating: #{result[:review].overall_rating}/10"
      
      puts "\n📋 Section Outline:"
      result[:outline].sections.each_with_index do |section, j|
        puts "   #{j+1}. #{section}"
      end
      
      puts "\n⭐ Review Strengths:"
      result[:review].strengths.each do |strength|
        puts "   • #{strength}"
      end
      
      puts "\n🔧 Suggested Improvements:"
      result[:review].improvements.each do |improvement|
        puts "   • #{improvement}"
      end
      
      puts "\n📝 Final Article Preview (first 200 chars):"
      preview = result[:final_content][0..200]
      puts "   #{preview}#{result[:final_content].length > 200 ? '...' : ''}"
      
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  puts "\n✅ Multi-stage Pipeline example completed!"
end

if __FILE__ == $0
  configure_dspy
  run_multi_stage_pipeline_example
end
