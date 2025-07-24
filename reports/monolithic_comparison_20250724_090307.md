# Monolithic Changelog Generation Comparison

**Date**: 2025-07-24 09:03:07
**PR Data**: May 2025 (5 PRs)
**Input Data Size**: 6359 characters

## Summary Table

| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |
|-------|--------|--------------|---------------|--------------|------|----------|
| claude-opus-4 | ✅ | 2756 | 307 | 3063 | $0.0644 | 11394.0ms |
| claude-opus-4-tweak | ✅ | 2345 | 347 | 2692 | $0.0612 | 11793.75ms |
| openai-4o | ✅ | 1783 | 19 | 1802 | $0.0092 | 1450.6ms |
| openai-o3 | ✅ | 2305 | 68 | 2373 | $0.0125 | 2286.35ms |
| openai-o4-mini-high | ✅ | 1967 | 122 | 2089 | $0.0004 | 3473.06ms |

**Total Cost**: $0.1477

## Detailed Results

### claude-opus-4

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 2756
- **Output Tokens**: 307
- **Total Tokens**: 3063
- **Cost Breakdown**:
  - Input: $0.0413
  - Output: $0.0230
  - **Total: $0.0644**
- **Duration**: 11394.0ms
- **Output Length**: 1225 characters
- **Output Saved**: `reports/outputs/claude-opus-4_20250724_090307.md`

### claude-opus-4-tweak

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 2345
- **Output Tokens**: 347
- **Total Tokens**: 2692
- **Cost Breakdown**:
  - Input: $0.0352
  - Output: $0.0260
  - **Total: $0.0612**
- **Duration**: 11793.75ms
- **Output Length**: 1390 characters
- **Output Saved**: `reports/outputs/claude-opus-4-tweak_20250724_090307.md`

### openai-4o

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 1783
- **Output Tokens**: 19
- **Total Tokens**: 1802
- **Cost Breakdown**:
  - Input: $0.0089
  - Output: $0.0003
  - **Total: $0.0092**
- **Duration**: 1450.6ms
- **Output Length**: 58 characters
- **Output Saved**: `reports/outputs/openai-4o_20250724_090307.md`

### openai-o3

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 2305
- **Output Tokens**: 68
- **Total Tokens**: 2373
- **Cost Breakdown**:
  - Input: $0.0115
  - Output: $0.0010
  - **Total: $0.0125**
- **Duration**: 2286.35ms
- **Output Length**: 276 characters
- **Output Saved**: `reports/outputs/openai-o3_20250724_090307.md`

### openai-o4-mini-high

- **Model**: `openai/gpt-4o-mini`
- **Success**: Yes
- **Input Tokens**: 1967
- **Output Tokens**: 122
- **Total Tokens**: 2089
- **Cost Breakdown**:
  - Input: $0.0003
  - Output: $0.0001
  - **Total: $0.0004**
- **Duration**: 3473.06ms
- **Output Length**: 501 characters
- **Output Saved**: `reports/outputs/openai-o4-mini-high_20250724_090307.md`

## Cost Analysis

### By Provider
- **Anthropic (Claude)**: $0.1256
- **OpenAI**: $0.0221

### Token Efficiency

| Model | Tokens per PR | Cost per 1K tokens |
|-------|---------------|-------------------|
| claude-opus-4 | 612.6 | $0.0210 |
| claude-opus-4-tweak | 538.4 | $0.0227 |
| openai-4o | 360.4 | $0.0051 |
| openai-o3 | 474.6 | $0.0053 |
| openai-o4-mini-high | 417.8 | $0.0002 |
