# Monolithic Changelog Generation Comparison

**Date**: 2025-07-24 15:35:11
**PR Data**: May 2025 (128 PRs)
**Input Data Size**: 321043 characters

## Summary Table

| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |
|-------|--------|--------------|---------------|--------------|------|----------|
| claude-opus-4 | ✅ | 109997 | 1587 | 111584 | $1.7690 | 57937.83ms |
| claude-opus-4-tweak | ✅ | 109586 | 1798 | 111384 | $1.7786 | 62051.07ms |
| openai-4o | ❌ | 0 | 0 | 0 | N/A | 1612.27ms |
| openai-o3 | ❌ | 0 | 0 | 0 | N/A | 1813.29ms |
| openai-o4-mini-high | ✅ | 95083 | 675 | 95758 | $0.0147 | 22338.94ms |

**Total Cost**: $3.5623

## Detailed Results

### claude-opus-4

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 109997
- **Output Tokens**: 1587
- **Total Tokens**: 111584
- **Cost Breakdown**:
  - Input: $1.6500
  - Output: $0.1190
  - **Total: $1.7690**
- **Duration**: 57937.83ms
- **Output Length**: 6476 characters
- **Output Saved**: `reports/outputs/claude-opus-4_20250724_153511.md`

### claude-opus-4-tweak

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: Yes
- **Input Tokens**: 109586
- **Output Tokens**: 1798
- **Total Tokens**: 111384
- **Cost Breakdown**:
  - Input: $1.6438
  - Output: $0.1348
  - **Total: $1.7786**
- **Duration**: 62051.07ms
- **Output Length**: 7539 characters
- **Output Saved**: `reports/outputs/claude-opus-4-tweak_20250724_153511.md`

### openai-4o

- **Model**: `openai/gpt-4o`
- **Success**: No
- **Error**: OpenAI adapter error: {:url=>"https://api.openai.com/v1/chat/completions", :status=>429, :body=>{:error=>{:message=>"Request too large for gpt-4o in organization org-nlRyAFTXZVIj5Ws33oGGalSK on tokens per min (TPM): Limit 30000, Requested 80715. The input or output tokens must be reduced in order to run successfully. Visit https://platform.openai.com/account/rate-limits to learn more.", :type=>"tokens", :param=>nil, :code=>"rate_limit_exceeded"}}}

### openai-o3

- **Model**: `openai/gpt-4o`
- **Success**: No
- **Error**: OpenAI adapter error: {:url=>"https://api.openai.com/v1/chat/completions", :status=>429, :body=>{:error=>{:message=>"Request too large for gpt-4o in organization org-nlRyAFTXZVIj5Ws33oGGalSK on tokens per min (TPM): Limit 30000, Requested 81297. The input or output tokens must be reduced in order to run successfully. Visit https://platform.openai.com/account/rate-limits to learn more.", :type=>"tokens", :param=>nil, :code=>"rate_limit_exceeded"}}}

### openai-o4-mini-high

- **Model**: `openai/gpt-4o-mini`
- **Success**: Yes
- **Input Tokens**: 95083
- **Output Tokens**: 675
- **Total Tokens**: 95758
- **Cost Breakdown**:
  - Input: $0.0143
  - Output: $0.0004
  - **Total: $0.0147**
- **Duration**: 22338.94ms
- **Output Length**: 2961 characters
- **Output Saved**: `reports/outputs/openai-o4-mini-high_20250724_153511.md`

## Cost Analysis

### By Provider
- **Anthropic (Claude)**: $3.5476
- **OpenAI**: $0.0147

### Token Efficiency

| Model | Tokens per PR | Cost per 1K tokens |
|-------|---------------|-------------------|
| claude-opus-4 | 871.8 | $0.0159 |
| claude-opus-4-tweak | 870.2 | $0.0160 |
| openai-o4-mini-high | 748.1 | $0.0002 |
