# DSPy.rb Provider-Specific Structured Output Strategies

## Overview

DSPy.rb 0.13.0 provides automatic structured output capabilities through provider-specific strategies. Rather than a generic "JSON mode", DSPy.rb intelligently selects the best strategy based on your LLM provider and model.

## Strategy Types

### 1. OpenAI Structured Output Strategy (`OpenAIStructuredOutputStrategy`)
- **Priority**: 100 (highest)
- **Requirements**: 
  - OpenAI adapter
  - `structured_outputs: true` in LM configuration
  - Model that supports structured outputs (e.g., gpt-4o-mini, gpt-4o)
- **How it works**: Uses OpenAI's native `response_format` parameter with JSON Schema
- **Reliability**: 100% - Guaranteed valid JSON matching your schema

### 2. Anthropic Tool Use Strategy (`AnthropicToolUseStrategy`)
- **Priority**: 95
- **Requirements**:
  - Anthropic adapter
  - Claude 3+ models (Opus, Sonnet, Haiku)
- **How it works**: Converts DSPy signatures to Anthropic tool definitions
- **Reliability**: 100% - Forces model to use the `json_output` tool

### 3. Anthropic Extraction Strategy (`AnthropicExtractionStrategy`)
- **Priority**: 90
- **Requirements**:
  - Anthropic adapter
  - Fallback for older models
- **How it works**: Uses 4-pattern matching to extract JSON from responses
- **Reliability**: >99.9% - Handles markdown-wrapped JSON and other formats

### 4. Enhanced Prompting Strategy (`EnhancedPromptingStrategy`)
- **Priority**: 50 (lowest)
- **Requirements**: Any LLM provider
- **How it works**: Adds strong JSON instructions to prompts
- **Reliability**: ~95% - Depends on model's instruction following

## Configuration

### Basic Setup

```ruby
DSPy.configure do |config|
  # For OpenAI with structured outputs
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
                          api_key: ENV['OPENAI_API_KEY'],
                          structured_outputs: true)
  
  # For Anthropic (automatically selects tool use or extraction)
  config.lm = DSPy::LM.new('anthropic/claude-3-haiku-20240307',
                          api_key: ENV['ANTHROPIC_API_KEY'])
end
```

### Advanced Configuration

```ruby
DSPy.configure do |config|
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
                          api_key: ENV['OPENAI_API_KEY'],
                          structured_outputs: true)
  
  # Strategy selection
  config.structured_outputs.strategy = DSPy::Strategy::Strict  # Provider-optimized
  # config.structured_outputs.strategy = DSPy::Strategy::Compatible  # Enhanced prompting
  
  # Retry configuration
  config.structured_outputs.retry_enabled = true
  config.structured_outputs.max_retries = 3
  
  # Fallback configuration
  config.structured_outputs.fallback_enabled = true
end
```

## Strategy Selection Process

1. **Manual Override**: If `config.structured_outputs.strategy` is set, DSPy tries to use that preference
2. **Automatic Selection**: Otherwise, DSPy selects the highest priority available strategy
3. **Fallback**: If a strategy fails, DSPy automatically falls back to the next available strategy

### Selection Logic

```
IF manual strategy preference is set THEN
  Try to use that strategy
  IF not available AND preference is Strict THEN
    Fall back to Compatible (enhanced prompting)
  END
ELSE
  Select highest priority available strategy:
  1. Try OpenAI structured outputs (if OpenAI + structured_outputs: true)
  2. Try Anthropic tool use (if Anthropic + Claude 3+)
  3. Try Anthropic extraction (if Anthropic)
  4. Use enhanced prompting (always available)
END
```

## Provider-Specific Implementation Details

### OpenAI
- Converts DSPy signatures to OpenAI JSON Schema format
- Adds `response_format` parameter to API calls
- Response is guaranteed to be valid JSON

### Anthropic
- **Tool Use**: Creates a `json_output` tool with schema from signature
- **Extraction**: Handles multiple JSON formats:
  - ` ```json` blocks
  - `## Output values` sections
  - Generic code blocks
  - Raw JSON

## Error Handling

Each strategy includes specific error handling:

```ruby
# OpenAI errors
"response_format" errors → Fallback to next strategy
"Invalid schema" errors → Fallback to next strategy

# Anthropic errors
"tool" errors → Fallback from tool use to extraction
"invalid_request_error" → Fallback to next strategy
```

## Best Practices

1. **Always enable structured outputs for OpenAI**:
   ```ruby
   config.lm = DSPy::LM.new('openai/...', structured_outputs: true)
   ```

2. **Use Strict strategy for production**:
   ```ruby
   config.structured_outputs.strategy = DSPy::Strategy::Strict
   ```

3. **Enable retries for reliability**:
   ```ruby
   config.structured_outputs.retry_enabled = true
   config.structured_outputs.max_retries = 3
   ```

4. **Let DSPy handle JSON extraction**:
   - Don't manually parse responses
   - Trust the automatic strategy selection
   - Use T::Struct for type safety

## Debugging

To see which strategy is being used:

```ruby
DSPy.logger.level = :debug
# DSPy will log: "Selected JSON extraction strategy: [strategy_name]"
```

## Migration from "JSON Mode"

If your code references "JSON mode", update it to use DSPy's structured outputs:

### Before
```ruby
# "JSON mode" - not a real DSPy feature
generator = JSONMode::BatchChangelogGenerator.new
```

### After
```ruby
# Proper DSPy structured outputs
DSPy.configure do |config|
  config.lm = DSPy::LM.new('openai/gpt-4o-mini', 
                          api_key: ENV['OPENAI_API_KEY'],
                          structured_outputs: true)
  config.structured_outputs.strategy = DSPy::Strategy::Strict
end

generator = StructuredOutput::BatchChangelogGenerator.new
```

## Summary

DSPy.rb's structured output system provides:
- Automatic provider-specific strategy selection
- 100% reliability with OpenAI and Anthropic Claude 3+
- Progressive fallback for maximum compatibility
- Type safety through T::Struct integration
- Built-in retry and error handling

There is no "JSON mode" - instead, DSPy.rb uses intelligent, provider-optimized strategies to ensure reliable structured outputs.