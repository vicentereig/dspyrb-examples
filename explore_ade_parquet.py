#!/usr/bin/env python
"""
Explore the downloaded ADE Corpus V2 parquet files to understand
the structure and how to use them for multi-step pipeline training.
"""

import pandas as pd
from pathlib import Path

def load_and_explore_parquet(file_path, config_name):
    """Load and explore a parquet file."""
    print(f"\n{'='*60}")
    print(f"Configuration: {config_name}")
    print('='*60)
    
    # Load the parquet file
    df = pd.read_parquet(file_path)
    
    print(f"Shape: {df.shape}")
    print(f"Columns: {list(df.columns)}")
    print(f"\nData types:")
    print(df.dtypes)
    
    print(f"\nFirst 3 rows:")
    for idx in range(min(3, len(df))):
        print(f"\n--- Row {idx} ---")
        row = df.iloc[idx]
        for col, val in row.items():
            if col == 'text':
                # Truncate long text
                text = str(val)[:150] + "..." if len(str(val)) > 150 else val
                print(f"  {col}: {text}")
            else:
                print(f"  {col}: {val}")
    
    # Statistics
    print(f"\nStatistics:")
    if 'label' in df.columns:
        print(f"  Label distribution:")
        print(df['label'].value_counts())
    
    if 'drug' in df.columns:
        # Count non-null drugs
        non_null_drugs = df['drug'].notna().sum()
        print(f"  Rows with drug annotations: {non_null_drugs}/{len(df)}")
    
    if 'effect' in df.columns:
        non_null_effects = df['effect'].notna().sum()
        print(f"  Rows with effect annotations: {non_null_effects}/{len(df)}")
    
    if 'dosage' in df.columns:
        non_null_dosage = df['dosage'].notna().sum()
        print(f"  Rows with dosage annotations: {non_null_dosage}/{len(df)}")
    
    return df

def analyze_text_alignment(dfs):
    """Check if texts align across configurations."""
    print("\n" + "="*60)
    print("Text Alignment Analysis")
    print("="*60)
    
    classification_df = dfs['classification']
    drug_ade_df = dfs['drug_ade']
    drug_dosage_df = dfs['drug_dosage']
    
    # Get unique texts from each
    class_texts = set(classification_df['text'].unique())
    drug_ade_texts = set(drug_ade_df['text'].unique())
    drug_dosage_texts = set(drug_dosage_df['text'].unique())
    
    print(f"\nUnique texts per configuration:")
    print(f"  Classification: {len(class_texts)} unique texts")
    print(f"  Drug-ADE: {len(drug_ade_texts)} unique texts")
    print(f"  Drug-Dosage: {len(drug_dosage_texts)} unique texts")
    
    # Check overlaps
    all_overlap = class_texts & drug_ade_texts & drug_dosage_texts
    class_drug_overlap = class_texts & drug_ade_texts
    
    print(f"\nOverlaps:")
    print(f"  All three configs share: {len(all_overlap)} texts")
    print(f"  Classification & Drug-ADE share: {len(class_drug_overlap)} texts")
    
    # Sample a text that appears in all three
    if all_overlap:
        sample_text = list(all_overlap)[0]
        print(f"\nExample text in all configs:")
        print(f"  Text: {sample_text[:200]}...")
        
        # Get all annotations for this text
        class_rows = classification_df[classification_df['text'] == sample_text]
        drug_ade_rows = drug_ade_df[drug_ade_df['text'] == sample_text]
        drug_dosage_rows = drug_dosage_df[drug_dosage_df['text'] == sample_text]
        
        print(f"\n  Classification label: {class_rows.iloc[0]['label']}")
        print(f"  Drug-ADE annotations: {len(drug_ade_rows)} rows")
        if len(drug_ade_rows) > 0:
            for _, row in drug_ade_rows.head(3).iterrows():
                print(f"    - Drug: {row['drug']}, Effect: {row['effect']}")
        print(f"  Drug-Dosage annotations: {len(drug_dosage_rows)} rows")
        if len(drug_dosage_rows) > 0:
            for _, row in drug_dosage_rows.head(3).iterrows():
                print(f"    - Drug: {row['drug']}, Dosage: {row.get('dosage', 'N/A')}")

def create_unified_view(dfs):
    """Create a unified view of the data for pipeline training."""
    print("\n" + "="*60)
    print("Creating Unified Dataset View")
    print("="*60)
    
    classification_df = dfs['classification']
    drug_ade_df = dfs['drug_ade']
    drug_dosage_df = dfs['drug_dosage']
    
    # Group drug-ade by text to get all annotations per text
    drug_ade_grouped = drug_ade_df.groupby('text').apply(
        lambda x: list(zip(x['drug'].fillna(''), x['effect'].fillna('')))
    ).to_dict()
    
    # Group drug-dosage by text  
    drug_dosage_grouped = drug_dosage_df.groupby('text').apply(
        lambda x: list(zip(x['drug'].fillna(''), x.get('dosage', pd.Series()).fillna('')))
    ).to_dict()
    
    # Create unified dataset
    unified_data = []
    for _, row in classification_df.iterrows():
        text = row['text']
        unified_row = {
            'text': text,
            'label': row['label'],
            'drug_effect_pairs': drug_ade_grouped.get(text, []),
            'drug_dosage_pairs': drug_dosage_grouped.get(text, [])
        }
        unified_data.append(unified_row)
    
    print(f"Created unified dataset with {len(unified_data)} examples")
    
    # Sample unified data
    print("\nSample unified records:")
    for i, record in enumerate(unified_data[:3]):
        print(f"\n--- Record {i} ---")
        print(f"  Text: {record['text'][:100]}...")
        print(f"  Label: {record['label']}")
        print(f"  Drug-Effect pairs: {len(record['drug_effect_pairs'])}")
        if record['drug_effect_pairs']:
            print(f"    First pair: {record['drug_effect_pairs'][0]}")
        print(f"  Drug-Dosage pairs: {len(record['drug_dosage_pairs'])}")
        if record['drug_dosage_pairs']:
            print(f"    First pair: {record['drug_dosage_pairs'][0]}")
    
    return unified_data

# Main exploration
if __name__ == "__main__":
    data_dir = Path("data/ade_corpus_v2")
    
    # Load all three configurations
    dfs = {}
    
    # Classification
    classification_file = data_dir / "Ade_corpus_v2_classification" / "train-00000-of-00001.parquet"
    dfs['classification'] = load_and_explore_parquet(classification_file, "Classification")
    
    # Drug-ADE Relation
    drug_ade_file = data_dir / "Ade_corpus_v2_drug_ade_relation" / "train-00000-of-00001.parquet"
    dfs['drug_ade'] = load_and_explore_parquet(drug_ade_file, "Drug-ADE Relation")
    
    # Drug-Dosage Relation
    drug_dosage_file = data_dir / "Ade_corpus_v2_drug_dosage_relation" / "train-00000-of-00001.parquet"
    dfs['drug_dosage'] = load_and_explore_parquet(drug_dosage_file, "Drug-Dosage Relation")
    
    # Analyze alignment
    analyze_text_alignment(dfs)
    
    # Create unified view
    unified_data = create_unified_view(dfs)
    
    print("\n" + "="*60)
    print("PIPELINE TRAINING STRATEGY")
    print("="*60)
    print("""
1. MedicalTextExtractor Training:
   - Input: Raw text
   - Output: Structured extractions (drugs, effects)
   - Training data: drug_ade_relation (6,821 annotations)
   
2. ADEPredictor Training:
   - Input: Text + Extracted features
   - Output: ADE classification (0/1)
   - Training data: classification labels (23,516 examples)
   
3. Multi-task Learning Opportunity:
   - Share text encoder between both components
   - Use drug-dosage data to enhance drug recognition
   - Leverage all 3 configs for comprehensive training
""")