# DSPy.rb Structured Output Implementation

## Key Insight

DSPy.rb 0.13.0 provides "structured outputs" through provider-specific strategies, not a generic "JSON mode". The efficiency comes from:

1. **Provider-Optimized Strategies**: Native OpenAI structured outputs, Anthropic tool use
2. **Automatic Strategy Selection**: DSPy.rb chooses the best strategy per provider
3. **Type-Safe Schemas**: T::Struct types ensure type safety and validation
4. **Built-in Retry Logic**: Automatic retries with progressive fallback strategies
5. **Smart JSON Extraction**: Provider-specific extraction patterns

## Implementation Strategy

### Current (Array-based) Approach
```ruby
# Multiple parallel arrays
output do
  const :theme_names, T::Array[String]
  const :theme_descriptions, T::Array[String]
  const :theme_pr_ids, T::Array[T::Array[Integer]]
  const :pr_ids_list, T::Array[Integer]
  const :pr_theme_assignments, T::Array[String]
end
```

### Structured Output (DSPy.rb) Approach
```ruby
# Configure DSPy with structured outputs enabled
DSPy.configure do |config|
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
                          api_key: ENV['OPENAI_API_KEY'],
                          structured_outputs: true)
  config.structured_outputs.strategy = DSPy::Strategy::Strict
  config.structured_outputs.retry_enabled = true
  config.structured_outputs.max_retries = 3
end

# Define output using T::Struct
output do
  const :analysis, BatchPRAnalysisOutput  # T::Struct with nested types
end
```

## Provider-Specific Strategies

### OpenAI
- Uses native `response_format` parameter
- Converts DSPy signatures to JSON Schema
- Highest reliability for structured outputs

### Anthropic
- Uses Tool Use API for guaranteed JSON
- Converts signatures to tool definitions
- Forces model to use `json_output` tool

### Fallback
- Enhanced prompting for other providers
- Smart JSON extraction from responses
- Progressive retry with exponential backoff

## Implementation Best Practices

1. **Enable Structured Outputs**: Set `structured_outputs: true` in LM config
2. **Use T::Struct Types**: Define all outputs as Sorbet structs
3. **Configure Strategy**: Use `DSPy::Strategy::Strict` for provider optimization
4. **Enable Retries**: Configure retry settings for reliability
5. **Let DSPy Handle Extraction**: Don't manually parse JSON responses