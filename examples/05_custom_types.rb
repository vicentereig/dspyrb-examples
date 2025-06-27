#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 5: Working with Complex Types
# This demonstrates DSPy.rb's type system capabilities with enums, optional fields, and structured data

require_relative '../setup'

# Complex type definitions
class Priority < T::Enum
  enums do
    Low = new('low')
    Medium = new('medium')
    High = new('high')
    Critical = new('critical')
  end
end

class Category < T::Enum
  enums do
    Bug = new('bug')
    Feature = new('feature')
    Documentation = new('documentation')
    Enhancement = new('enhancement')
  end
end

class TaskAnalyzer < DSPy::Signature
  description "Analyze a task description and extract structured information"
  
  input do
    const :task_description, String
  end
  
  output do
    const :title, String
    const :category, Category
    const :priority, Priority
    const :estimated_hours, Float
    const :tags, T::Array[String]
    const :complexity_score, Integer  # 1-10 scale
  end
end

class ProjectPlanner < DSPy::Signature
  description "Create a project plan with timeline and milestones"
  
  class Milestone < T::Struct
    const :name, String
    const :description, String
    const :due_weeks, Integer
    const :dependencies, T::Array[String]
  end
  
  input do
    const :project_name, String
    const :requirements, T::Array[String]
    const :team_size, Integer
  end
  
  output do
    const :project_duration_weeks, Integer
    const :milestones, T::Array[Milestone]
    const :risk_level, Priority
    const :recommended_technologies, T::Array[String]
  end
end

class RecipeOptimizer < DSPy::Signature
  description "Optimize recipes based on dietary preferences and constraints"
  
  class DietaryRestriction < T::Enum
    enums do
      None = new('none')
      Vegetarian = new('vegetarian')
      Vegan = new('vegan')
      GlutenFree = new('gluten_free')
      Keto = new('keto')
      LowSodium = new('low_sodium')
    end
  end
  
  class Ingredient < T::Struct
    const :name, String
    const :amount, String
    const :substitutions, T::Array[String]
  end
  
  input do
    const :original_recipe, String
    const :dietary_restrictions, T::Array[DietaryRestriction]
    const :serving_size, Integer
  end
  
  output do
    const :optimized_ingredients, T::Array[Ingredient]
    const :cooking_time_minutes, Integer
    const :difficulty_level, Integer  # 1-5 scale
    const :nutritional_highlights, T::Array[String]
    const :chef_tips, T::Array[String]
  end
end

def run_complex_types_example
  puts "🎯 Complex Types and Structured Data Example"
  puts "=" * 60
  
  # Task Analysis
  puts "\n📋 Task Analysis:"
  puts "-" * 30
  
  task_analyzer = DSPy::Predict.new(TaskAnalyzer)
  
  tasks = [
    "Fix the login bug where users can't authenticate with OAuth providers",
    "Add a dark mode toggle to the user interface",
    "Write comprehensive API documentation for the new endpoints",
    "Implement real-time notifications using WebSockets"
  ]
  
  tasks.each_with_index do |task, i|
    puts "\n#{i+1}. Task: #{task}"
    
    begin
      result = task_analyzer.call(task_description: task)
      puts "   Title: #{result.title}"
      puts "   Category: #{result.category}"
      puts "   Priority: #{result.priority}"
      puts "   Est. Hours: #{result.estimated_hours}"
      puts "   Complexity: #{result.complexity_score}/10"
      puts "   Tags: #{result.tags.join(', ')}"
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  # Project Planning
  puts "\n\n🚀 Project Planning:"
  puts "-" * 30
  
  project_planner = DSPy::ChainOfThought.new(ProjectPlanner)
  
  projects = [
    {
      name: "E-commerce Mobile App",
      requirements: ["User authentication", "Product catalog", "Shopping cart", "Payment integration", "Order tracking"],
      team_size: 4
    },
    {
      name: "Task Management Dashboard",
      requirements: ["User management", "Project boards", "Real-time collaboration", "Reporting", "API integration"],
      team_size: 3
    }
  ]
  
  projects.each_with_index do |project, i|
    puts "\n#{i+1}. Project: #{project[:name]}"
    
    begin
      result = project_planner.call(
        project_name: project[:name],
        requirements: project[:requirements],
        team_size: project[:team_size]
      )
      
      puts "   Duration: #{result.project_duration_weeks} weeks"
      puts "   Risk Level: #{result.risk_level}"
      puts "   Technologies: #{result.recommended_technologies.join(', ')}"
      puts "   Milestones:"
      
      result.milestones.each_with_index do |milestone, j|
        puts "     #{j+1}. #{milestone.name} (Week #{milestone.due_weeks})"
        puts "        #{milestone.description}"
        unless milestone.dependencies.empty?
          puts "        Dependencies: #{milestone.dependencies.join(', ')}"
        end
      end
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  # Recipe Optimization
  puts "\n\n👨‍🍳 Recipe Optimization:"
  puts "-" * 30
  
  recipe_optimizer = DSPy::Predict.new(RecipeOptimizer)
  
  recipes = [
    {
      recipe: "Classic Spaghetti Carbonara with eggs, bacon, parmesan cheese, and black pepper",
      restrictions: [RecipeOptimizer::DietaryRestriction::Vegetarian],
      servings: 4
    },
    {
      recipe: "Chocolate chip cookies with flour, sugar, butter, eggs, and chocolate chips",
      restrictions: [RecipeOptimizer::DietaryRestriction::GlutenFree, RecipeOptimizer::DietaryRestriction::Vegan],
      servings: 12
    }
  ]
  
  recipes.each_with_index do |recipe_info, i|
    puts "\n#{i+1}. Recipe: #{recipe_info[:recipe]}"
    puts "   Restrictions: #{recipe_info[:restrictions].map(&:serialize).join(', ')}"
    
    begin
      result = recipe_optimizer.call(
        original_recipe: recipe_info[:recipe],
        dietary_restrictions: recipe_info[:restrictions],
        serving_size: recipe_info[:servings]
      )
      
      puts "   Cooking Time: #{result.cooking_time_minutes} minutes"
      puts "   Difficulty: #{result.difficulty_level}/5"
      puts "   Optimized Ingredients:"
      
      result.optimized_ingredients.each do |ingredient|
        puts "     • #{ingredient.amount} #{ingredient.name}"
        unless ingredient.substitutions.empty?
          puts "       Substitutions: #{ingredient.substitutions.join(', ')}"
        end
      end
      
      puts "   Nutritional Highlights:"
      result.nutritional_highlights.each { |highlight| puts "     • #{highlight}" }
      
      puts "   Chef Tips:"
      result.chef_tips.each { |tip| puts "     • #{tip}" }
      
    rescue StandardError => e
      puts "   Error: #{e.message}"
    end
  end
  
  puts "\n✅ Complex Types example completed!"
end

if __FILE__ == $0
  configure_dspy
  run_complex_types_example
end
