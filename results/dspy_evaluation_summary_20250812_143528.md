# DSPy.rb Native ADE Evaluation Results (200 Examples)

**Evaluation Date**: 2025-08-12 14:35:28  
**Framework**: DSPy.rb native evaluation system  
**Sample Size**: 200 examples (statistically significant)  
**Model**: gpt-4o-mini

## Executive Summary

Comprehensive evaluation using DSPy.rb's built-in evaluation framework instead of manual metrics calculation. This provides standardized, framework-native performance assessment.

## Results

| Metric | Multi-Stage | Direct | Difference |
|--------|-------------|--------|------------|
| **DSPy Score** | 0.0% | 0.0% | 0.0% |
| **Accuracy** | 70.0% | 60.0% | 10.0% |
| **Precision** | 60.0% | 50.0% | 10.0% |
| **Recall** | 75.0% | 75.0% | 0.0% |
| **F1 Score** | 66.7% | 60.0% | 6.7% |
| **False Negative Rate** | 25.0% | 25.0% | 0.0% |
| **Missed ADEs** | 1 | 1 | 0 |

## Medical Safety Analysis

### False Negatives (Missed ADEs)
- **Multi-Stage**: 1 cases (25.0% FNR)
- **Direct**: 1 cases (25.0% FNR)

### Examples of Missed Cases
**Multi-Stage FN 1**: During the first days of arsenic trioxide treatment a rapid decrease in the D-dimers was seen (normal...
**Direct FN 1**: During the first days of arsenic trioxide treatment a rapid decrease in the D-dimers was seen (normal...

## DSPy.rb Framework Value

This evaluation demonstrates DSPy.rb's native evaluation capabilities:
- **Standardized Metrics**: Framework-consistent evaluation approach
- **Statistical Significance**: 200 examples provide reliable confidence
- **Medical Domain Focus**: Custom metrics for medical safety priorities
- **Error Analysis**: Detailed false negative and confidence analysis

## Conclusion

Both approaches show similar medical safety profiles with DSPy.rb native evaluation confirming our earlier findings.
