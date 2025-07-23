# Monolithic Changelog Generation Comparison

**Date**: 2025-01-23 10:30:00
**PR Data**: May 2025 (127 PRs)
**Input Data Size**: 325,579 characters

## Summary Table

| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |
|-------|--------|--------------|---------------|--------------|------|----------|
| claude-opus-4 | ✅ | 81,395 | 1,507 | 82,902 | $1.3342 | 15234ms |
| claude-opus-4-tweak | ✅ | 74,152 | 1,344 | 75,496 | $1.2131 | 13892ms |
| openai-4o | ✅ | 74,797 | 54 | 74,851 | $0.3749 | 8453ms |
| openai-o3 | ✅ | 75,330 | 186 | 75,516 | $0.3794 | 9221ms |
| openai-o4-mini-high | ✅ | 74,910 | 1,487 | 76,397 | $0.0203 | 6732ms |

**Total Cost**: $3.3219

## Detailed Results

### claude-opus-4

- **Model**: `anthropic/claude-3-opus-20240229`
- **Success**: Yes
- **Input Tokens**: 81,395
- **Output Tokens**: 1,507
- **Total Tokens**: 82,902
- **Cost Breakdown**:
  - Input: $1.2209
  - Output: $0.1133
  - **Total: $1.3342**
- **Duration**: 15234ms
- **Output Length**: 6,028 characters
- **Output Saved**: `reports/outputs/claude-opus-4_20250123_103000.md`

### claude-opus-4-tweak

- **Model**: `anthropic/claude-3-opus-20240229`
- **Success**: Yes
- **Input Tokens**: 74,152
- **Output Tokens**: 1,344
- **Total Tokens**: 75,496
- **Cost Breakdown**:
  - Input: $1.1123
  - Output: $0.1008
  - **Total: $1.2131**
- **Duration**: 13892ms
- **Output Length**: 5,376 characters
- **Output Saved**: `reports/outputs/claude-opus-4-tweak_20250123_103000.md`

### openai-4o

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 74,797
- **Output Tokens**: 54
- **Total Tokens**: 74,851
- **Cost Breakdown**:
  - Input: $0.3740
  - Output: $0.0009
  - **Total: $0.3749**
- **Duration**: 8453ms
- **Output Length**: 215 characters
- **Output Saved**: `reports/outputs/openai-4o_20250123_103000.md`

### openai-o3

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 75,330
- **Output Tokens**: 186
- **Total Tokens**: 75,516
- **Cost Breakdown**:
  - Input: $0.3767
  - Output: $0.0027
  - **Total: $0.3794**
- **Duration**: 9221ms
- **Output Length**: 743 characters
- **Output Saved**: `reports/outputs/openai-o3_20250123_103000.md`

### openai-o4-mini-high

- **Model**: `openai/gpt-4o-mini`
- **Success**: Yes
- **Input Tokens**: 74,910
- **Output Tokens**: 1,487
- **Total Tokens**: 76,397
- **Cost Breakdown**:
  - Input: $0.0112
  - Output: $0.0091
  - **Total: $0.0203**
- **Duration**: 6732ms
- **Output Length**: 5,945 characters
- **Output Saved**: `reports/outputs/openai-o4-mini-high_20250123_103000.md`

## Cost Analysis

### By Provider

- **Anthropic (Claude)**: $2.5473
- **OpenAI**: $0.7746

### Token Efficiency

| Model | Tokens per PR | Cost per 1K tokens |
|-------|---------------|-------------------|
| claude-opus-4 | 652.8 | $0.0161 |
| claude-opus-4-tweak | 594.5 | $0.0161 |
| openai-4o | 589.4 | $0.0050 |
| openai-o3 | 594.6 | $0.0050 |
| openai-o4-mini-high | 601.6 | $0.0003 |