# Monolithic Changelog Generation Comparison

**Date**: 2025-07-24 09:00:47
**PR Data**: May 2025 (1 PRs)
**Input Data Size**: 1762 characters

## Summary Table

| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |
|-------|--------|--------------|---------------|--------------|------|----------|
| claude-opus-4 | ✅ | 1546 | 237 | 1783 | $0.0410 | 8214.2ms |
| claude-opus-4-tweak | ✅ | 1135 | 276 | 1411 | $0.0377 | 8611.06ms |
| openai-4o | ✅ | 717 | 19 | 736 | $0.0039 | 1875.56ms |
| openai-o3 | ✅ | 1239 | 66 | 1305 | $0.0072 | 2616.75ms |
| openai-o4-mini-high | ✅ | 901 | 70 | 971 | $0.0002 | 4090.37ms |

**Total Cost**: $0.0899

## Detailed Results

### claude-opus-4

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 1546
- **Output Tokens**: 237
- **Total Tokens**: 1783
- **Cost Breakdown**:
  - Input: $0.0232
  - Output: $0.0178
  - **Total: $0.0410**
- **Duration**: 8214.2ms
- **Output Length**: 922 characters
- **Output Saved**: `reports/outputs/claude-opus-4_20250724_090047.md`

### claude-opus-4-tweak

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 1135
- **Output Tokens**: 276
- **Total Tokens**: 1411
- **Cost Breakdown**:
  - Input: $0.0170
  - Output: $0.0207
  - **Total: $0.0377**
- **Duration**: 8611.06ms
- **Output Length**: 1124 characters
- **Output Saved**: `reports/outputs/claude-opus-4-tweak_20250724_090047.md`

### openai-4o

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 717
- **Output Tokens**: 19
- **Total Tokens**: 736
- **Cost Breakdown**:
  - Input: $0.0036
  - Output: $0.0003
  - **Total: $0.0039**
- **Duration**: 1875.56ms
- **Output Length**: 58 characters
- **Output Saved**: `reports/outputs/openai-4o_20250724_090047.md`

### openai-o3

- **Model**: `openai/gpt-4o`
- **Success**: Yes
- **Input Tokens**: 1239
- **Output Tokens**: 66
- **Total Tokens**: 1305
- **Cost Breakdown**:
  - Input: $0.0062
  - Output: $0.0010
  - **Total: $0.0072**
- **Duration**: 2616.75ms
- **Output Length**: 274 characters
- **Output Saved**: `reports/outputs/openai-o3_20250724_090047.md`

### openai-o4-mini-high

- **Model**: `openai/gpt-4o-mini`
- **Success**: Yes
- **Input Tokens**: 901
- **Output Tokens**: 70
- **Total Tokens**: 971
- **Cost Breakdown**:
  - Input: $0.0001
  - Output: $0.0000
  - **Total: $0.0002**
- **Duration**: 4090.37ms
- **Output Length**: 287 characters
- **Output Saved**: `reports/outputs/openai-o4-mini-high_20250724_090047.md`

## Cost Analysis

### By Provider
- **Anthropic (Claude)**: $0.0787
- **OpenAI**: $0.0112

### Token Efficiency

| Model | Tokens per PR | Cost per 1K tokens |
|-------|---------------|-------------------|
| claude-opus-4 | 1783.0 | $0.0230 |
| claude-opus-4-tweak | 1411.0 | $0.0267 |
| openai-4o | 736.0 | $0.0053 |
| openai-o3 | 1305.0 | $0.0055 |
| openai-o4-mini-high | 971.0 | $0.0002 |
