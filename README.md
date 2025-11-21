
Moved over to https://github.com/vicentereig/dspy.rb/tree/main/examples

# DSPy.rb Examples Repository

A comprehensive collection of examples demonstrating the power of DSPy.rb - the Ruby framework for programming language models.

Library repo: https://github.com/vicentereig/dspy.rb

## 📋 Prerequisites

- **Ruby 3.3.5** (specified in Gemfile)
- **OpenAI API key** (recommended) or Anthropic API key
- **Bundler** for dependency management
- **Internet connection** for API calls

## 🚀 Quick Start

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Configure API key:**
   ```bash
   cp .env.example .env
   # Edit .env and add your OpenAI API key
   ```

3. **Run examples:**
   ```bash
   # Interactive mode
   ruby main.rb

   # List all examples
   ruby main.rb --list

   # Run specific example
   ruby main.rb --run 1

   # Run all examples
   ruby main.rb --all
   ```

## 📚 Available Examples

### 1. Basic Prediction (`01_basic_predict.rb`)
- **Pattern**: `DSPy::Predict`
- **Description**: Demonstrates simple structured prediction with sentiment classification
- **Features**: Custom enum types, structured output, confidence scoring
- **Use Cases**: Text classification, sentiment analysis, basic categorization

### 2. Chain of Thought (`02_chain_of_thought.rb`)
- **Pattern**: `DSPy::ChainOfThought`
- **Description**: Shows reasoning capabilities with math problems and general Q&A
- **Features**: Automatic reasoning field injection, detailed explanations
- **Use Cases**: Complex problem solving, educational content, step-by-step analysis

### 3. ReAct Agent with Tools (`03_react_agent.rb`)
- **Pattern**: `DSPy::ReAct`
- **Description**: Intelligent agent that can use tools to solve complex problems
- **Features**: Custom tool definitions, multi-step reasoning, tool selection
- **Tools Included**: Calculator, unit converter, datetime utilities
- **Use Cases**: Mathematical calculations, data conversion, multi-step workflows

### 4. Multi-stage Pipeline (`04_multi_stage_pipeline.rb`)
- **Pattern**: `DSPy::Module` with composed workflows
- **Description**: Complex article writing pipeline with outline generation, section writing, and review
- **Features**: Multi-step workflows, content generation, automated review
- **Use Cases**: Content creation, document generation, quality assurance workflows

### 5. Complex Types & Structured Data (`05_custom_types.rb`)
- **Pattern**: Advanced type system usage
- **Description**: Task analysis, project planning, and recipe optimization with complex types
- **Features**: Custom enums, structs, arrays, optional fields
- **Use Cases**: Data modeling, structured analysis, complex business logic

## 🏗️ Project Structure

```
dspyrb-examples/
├── Gemfile                           # Ruby dependencies and version
├── setup.rb                         # Shared DSPy configuration
├── main.rb                          # Interactive runner with CLI options
├── run_example.rb                   # Quick runner for individual examples
├── .env.example                     # Environment variables template
├── .env                             # Your actual environment variables (create this)
├── examples/                        # Individual example files
│   ├── 01_basic_predict.rb         # Basic prediction patterns
│   ├── 02_chain_of_thought.rb      # Reasoning with CoT
│   ├── 03_react_agent.rb           # Tool-using agents
│   ├── 04_multi_stage_pipeline.rb  # Complex workflows
│   └── 05_custom_types.rb          # Advanced type usage
└── README.md                        # This file
```

## 🎯 DSPy.rb Core Concepts

### Signatures
Define input/output schemas using Sorbet types:
```ruby
class MySignature < DSPy::Signature
  description "What this signature does"
  
  input do
    const :field_name, String
  end
  
  output do 
    const :result, String
  end
end
```

### Predictors
- **Predict**: Basic LLM completion with structured output
- **ChainOfThought**: Adds automatic reasoning steps
- **ReAct**: Tool-using agents for complex problem solving

### Tools
Create custom tools for ReAct agents:
```ruby
class MyTool < DSPy::Tools::Base
  tool_name 'my_tool'
  tool_description 'What this tool does'
  
  def call(param:)
    # Tool implementation
  end
end
```

### Complex Types
Define structured data with enums and custom types:
```ruby
class Priority < T::Enum
  enums do
    Low = new('low')
    High = new('high')
  end
end

class Task < T::Struct
  const :title, String
  const :priority, Priority
end
```

## 🔧 Usage Examples

### Method 1: Interactive Main Runner
```bash
# Start interactive mode
ruby main.rb

# Follow the prompts to:
# - List available examples (l)
# - Run specific example (1-5)
# - Run all examples (a)
# - Quit (q)
```

### Method 2: Command Line Options
```bash
# List all available examples
ruby main.rb --list

# Run specific example by number
ruby main.rb --run 1
ruby main.rb --run 3

# Run all examples in sequence
ruby main.rb --all

# Show help
ruby main.rb --help
```

### Method 3: Quick Runner
```bash
# Fast way to run individual examples
ruby run_example.rb 1  # Basic prediction
ruby run_example.rb 2  # Chain of thought
ruby run_example.rb 3  # ReAct agent
ruby run_example.rb 4  # Multi-stage pipeline
ruby run_example.rb 5  # Complex types
```

### Method 4: Direct Execution
```bash
# Run example files directly
ruby examples/01_basic_predict.rb
ruby examples/02_chain_of_thought.rb
ruby examples/03_react_agent.rb
ruby examples/04_multi_stage_pipeline.rb
ruby examples/05_custom_types.rb
```

## 🛠️ Troubleshooting

### Common Issues

**API Key Issues:**
- Ensure your `.env` file exists and contains `OPENAI_API_KEY=your_actual_key`
- Verify the API key is valid and has sufficient credits
- Check that the `.env` file is in the project root directory

**Ruby Version Issues:**
- Ensure you're using Ruby 3.3.5 (check with `ruby --version`)
- Use a Ruby version manager like rbenv or RVM if needed

**Gem Installation Issues:**
```bash
# If bundle install fails, try:
gem install bundler
bundle install --verbose

# If DSPy.rb fails to install:
bundle update
```

**Type Errors:**
- DSPy.rb uses Sorbet for runtime type checking
- Ensure your inputs match the expected types in signatures
- Check enum values are properly defined

**Network/API Errors:**
- Verify internet connection
- Check API service status
- Ensure API key has proper permissions

### Debug Mode
Enable debug output by setting environment variable:
```bash
DEBUG=true ruby main.rb --run 1
```

### Environment Variables
Required:
- `OPENAI_API_KEY`: Your OpenAI API key

Optional:
- `ANTHROPIC_API_KEY`: Anthropic API key (alternative to OpenAI)
- `DEBUG`: Enable debug logging
- `AUTO_RUN`: Skip pauses in --all mode

## 🧪 Extending Examples

### Adding New Examples
1. Create a new file in `examples/` directory
2. Follow the existing pattern with `require_relative '../setup'`
3. Add example to `EXAMPLES` hash in `main.rb` and `run_example.rb`
4. Update this README

### Creating Custom Tools
```ruby
class MyCustomTool < DSPy::Tools::Base
  tool_name 'my_tool'
  tool_description 'Description of what this tool does'
  
  sig { params(param1: String, param2: Integer).returns(String) }
  def call(param1:, param2:)
    # Your tool logic here
    "Result: #{param1} processed with #{param2}"
  end
end
```

### Defining Complex Signatures
```ruby
class ComplexSignature < DSPy::Signature
  description "A complex signature example"
  
  class Status < T::Enum
    enums do
      Active = new('active')
      Inactive = new('inactive')
    end
  end
  
  class Item < T::Struct
    const :name, String
    const :value, Float
    const :status, Status
  end
  
  input do
    const :data, T::Array[String]
    const :options, T::Hash[String, T.any(String, Integer)]
  end
  
  output do
    const :items, T::Array[Item]
    const :summary, String
    const :confidence, Float
  end
end
```

## 📖 Learning Path

1. **Start with Basic Prediction** (`01_basic_predict.rb`)
   - Understand DSPy signatures and basic prediction
   - Learn about type safety and structured outputs

2. **Explore Chain of Thought** (`02_chain_of_thought.rb`)
   - See how reasoning improves output quality
   - Understand automatic reasoning injection

3. **Try ReAct Agents** (`03_react_agent.rb`)
   - Learn about tool-using agents
   - Understand multi-step problem solving

4. **Build Complex Workflows** (`04_multi_stage_pipeline.rb`)
   - Compose multiple LLM calls
   - Create end-to-end content generation

5. **Master Type System** (`05_custom_types.rb`)
   - Advanced enum and struct usage
   - Complex data modeling

## 🌟 Next Steps

Try modifying the examples to:
- Add new signature types for your use case
- Create custom tools for your domain
- Build multi-stage pipelines for your workflows
- Experiment with different LLM providers
- Integrate with your existing Ruby applications

## 📚 Resources

- [DSPy.rb GitHub Repository](https://github.com/vicentereig/dspy.rb)
- [Original DSPy Documentation](https://dspy.ai/)
- [Sorbet Type System](https://sorbet.org/)
- [Ruby LLM Integration](https://github.com/crmne/ruby_llm)
