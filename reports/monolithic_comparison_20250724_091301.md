# Monolithic Changelog Generation Comparison

**Date**: 2025-07-24 09:13:01
**PR Data**: May 2025 (128 PRs)
**Input Data Size**: 321043 characters

## Summary Table

| Model | Status | Input Tokens | Output Tokens | Total Tokens | Cost | Duration |
|-------|--------|--------------|---------------|--------------|------|----------|
| claude-opus-4 | ❌ | 0 | 0 | 0 | N/A | 25228.47ms |
| claude-opus-4-tweak | ❌ | 0 | 0 | 0 | N/A | 2131.38ms |
| openai-4o | ❌ | 0 | 0 | 0 | N/A | 2239.73ms |
| openai-o3 | ❌ | 0 | 0 | 0 | N/A | 1872.84ms |
| openai-o4-mini-high | ✅ | 95083 | 2376 | 97459 | $0.0157 | 87732.58ms |

**Total Cost**: $0.0157

## Detailed Results

### claude-opus-4

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: No
- **Error**: Anthropic adapter error: {:url=>"https://api.anthropic.com/v1/messages", :status=>529, :body=>{:type=>"error", :error=>{:type=>"overloaded_error", :message=>"Overloaded"}}}

### claude-opus-4-tweak

- **Model**: `anthropic/claude-opus-4-20250514`
- **Success**: No
- **Error**: Anthropic adapter error: {:url=>"https://api.anthropic.com/v1/messages", :status=>500, :body=>{:type=>"error", :error=>{:type=>"api_error", :message=>"Overloaded"}}}

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
- **Output Tokens**: 2376
- **Total Tokens**: 97459
- **Cost Breakdown**:
  - Input: $0.0143
  - Output: $0.0014
  - **Total: $0.0157**
- **Duration**: 87732.58ms
- **Output Length**: 10433 characters
- **Output Saved**: `reports/outputs/openai-o4-mini-high_20250724_091301.md`

## Cost Analysis

### By Provider
- **Anthropic (Claude)**: $0.0000
- **OpenAI**: $0.0157

### Token Efficiency

| Model | Tokens per PR | Cost per 1K tokens |
|-------|---------------|-------------------|
| openai-o4-mini-high | 761.4 | $0.0002 |
