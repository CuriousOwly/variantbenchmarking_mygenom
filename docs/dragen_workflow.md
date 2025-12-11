# DRAGEN SV Benchmarking Workflow

This pipeline now supports DRAGEN's recommended workflow for benchmarking structural variant (SV) VCFs following Illumina's official guidelines.

## Overview

The DRAGEN workflow includes:
1. **DRAGEN-specific preprocessing** - Filters VCFs according to DRAGEN/NIST recommendations
2. **Truvari bench** - Initial benchmarking against truth set
3. **Truvari refine** - Sequence alignment-based refinement for improved accuracy
4. **nf-core reporting** - Comprehensive reports with metrics, plots, and MultiQC

## DRAGEN-Specific Preprocessing

### Truth VCF Filtering
- **Removes**: `ALT="*"` records as recommended by NIST
- **Reason**: These records represent reference-only sites that can confuse benchmarking tools

### Query VCF Filtering (DRAGEN output)
- **Removes**: `ALT="<DUP:TANDEM>"` symbolic alleles
- **Reason**: DRAGEN reports tandem duplications >1000bp with symbolic alleles instead of sequences, which cannot be refined by truvari

### Activation
Add `filter_dragen` to the `--preprocess` parameter:
```bash
--preprocess "filter_dragen,normalize,deduplicate"
```

## Truvari Refine

Truvari refine performs sequence alignment (using MAFFT) on candidate variants to reclassify TP/FP/FN calls with higher accuracy.

### Activation
```bash
--truvari_refine true
```

### Parameters
Default parameters (configured in `conf/modules.config`):
- `--align mafft` - Use MAFFT for sequence alignment
- `--threads 4` - Parallel alignment threads
- `--use-original-vcfs` - Use original VCF files for refinement
- `--use-region-coords` - Use region coordinates for matching
- `--recount` - Recount TP/FP/FN after refinement

## Complete DRAGEN Workflow Example

### 1. Input Files

**Truth Set** (NIST T2T Q100 v1.1):
```bash
truth_vcf="GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz"
truth_bed="GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed"
```

**Query VCF** (DRAGEN output):
```bash
query_vcf="HG002.dragen.sv.vcf.gz"
```

### 2. Samplesheet (`samplesheet.csv`)

```csv
id,test_vcf,caller,subsample,pctsize,pctseq,pctovl,refdist,chunksize
HG002_dragen,HG002.dragen.sv.vcf.gz,dragen,,0.7,0.7,0.0,2000,5000
```

**Key parameters** (matching DRAGEN recommendations):
- `pctsize`: 0.7 - Size similarity threshold
- `pctseq`: 0.7 - Sequence similarity threshold
- `pctovl`: 0.0 - Overlap threshold
- `refdist`: 2000 - Maximum distance between breakpoints
- `chunksize`: 5000 - Chunking parameter

### 3. Command

```bash
nextflow run /path/to/variantbenchmarking \
  --input samplesheet.csv \
  --genome GRCh38 \
  --fasta GRCh38.fasta \
  --analysis germline \
  --variant_type structural \
  --method truvari \
  --test_vcf_sv_caller dragen \
  --truth_vcf ${truth_vcf} \
  --truth_high_conf ${truth_bed} \
  --truth_id T2TQ100 \
  --sv_standardization "svync" \
  --preprocess "filter_dragen,normalize,deduplicate" \
  --truvari_refine true \
  --outdir results_dragen_workflow \
  -profile docker
```

### 4. Key Parameters Explained

- `--test_vcf_sv_caller dragen` - Enables DRAGEN-specific VCF reformatting (svync)
- `--preprocess "filter_dragen,normalize,deduplicate"` - Applies DRAGEN filters + standard preprocessing
- `--sv_standardization "svync"` - Converts DRAGEN fields to standard format
- `--truvari_refine true` - Runs truvari refine after bench for improved accuracy

## Output Structure

```
results_dragen_workflow/
├── structural/
│   └── HG002_dragen/
│       ├── benchmarks/
│       │   └── truvari/
│       │       ├── HG002_dragen.T2TQ100.dragen.summary.json        # Initial bench results
│       │       ├── HG002_dragen.T2TQ100.dragen.refined.summary.json  # Refined results ⭐
│       │       ├── HG002_dragen.T2TQ100.dragen.refine.log          # Refine log
│       │       ├── HG002_dragen.T2TQ100.dragen.fn.vcf.gz           # False Negatives
│       │       ├── HG002_dragen.T2TQ100.dragen.fp.vcf.gz           # False Positives
│       │       ├── HG002_dragen.T2TQ100.dragen.tp-base.vcf.gz      # True Positives (truth)
│       │       └── HG002_dragen.T2TQ100.dragen.tp-comp.vcf.gz      # True Positives (DRAGEN)
│       └── preprocessing/
│           ├── test/
│           │   └── HG002_dragen.dragen.processed.vcf.gz  # Filtered DRAGEN VCF
│           └── truth/
│               └── T2TQ100.processed.vcf.gz              # Filtered truth VCF
├── reports/
│   └── truvari/
│       ├── merged_report.csv                   # Consolidated metrics (uses refined if available)
│       ├── precision_recall.pdf                # Performance plots
│       ├── sv_length_distribution.pdf          # SV size analysis
│       └── truvari_interactive_report.html     # Datavzrd interactive report
└── multiqc_report.html                         # Complete QC dashboard

```

## Comparing Bench vs Refine Results

The pipeline will use **refined results** for reporting when `--truvari_refine true` is set.

**Expected improvements from refinement**:
- More accurate TP/FP/FN classification
- Better handling of complex/imprecise SVs
- Improved precision (fewer false positives)
- Slightly lower recall (stricter matching)

**To compare**:
```bash
# View initial bench results
cat results/structural/HG002_dragen/benchmarks/truvari/HG002_dragen.T2TQ100.dragen.summary.json

# View refined results (used in reports)
cat results/structural/HG002_dragen/benchmarks/truvari/HG002_dragen.T2TQ100.dragen.refined.summary.json
```

## Recommended NIST T2T Q100 Truth Sets

**For GRCh38-aligned samples**:
- **HG002** (Ashkenazi Trio son): `GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz`
- Download from: https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/analysis/NIST_HG002_T2T_Q100_v1.1/

**Important**: The "T2T Q100" truth set is **GRCh38-based** (not T2T-CHM13 reference). The "T2T Q100" refers to the high-quality PacBio HiFi sequencing data used to create the truth set.

## Differences from Standard Workflow

| Feature | Standard Workflow | DRAGEN Workflow |
|---------|------------------|-----------------|
| **Truth VCF preprocessing** | Standard normalization | + Filter `ALT="*"` records |
| **Query VCF preprocessing** | Standard normalization | + Filter `<DUP:TANDEM>` alleles |
| **Benchmarking** | truvari bench only | truvari bench + refine |
| **Truvari parameters** | Default values | DRAGEN-optimized (refdist=2000, etc.) |
| **Reporting** | Uses bench results | Uses refined results ⭐ |
| **Use case** | General SV benchmarking | DRAGEN SV validation |

## Best Practices

1. **Always use DRAGEN-specific filtering** for DRAGEN VCFs:
   ```bash
   --preprocess "filter_dragen,normalize,deduplicate"
   ```

2. **Enable truvari refine** for most accurate results:
   ```bash
   --truvari_refine true
   ```

3. **Use NIST T2T Q100 truth sets** for HG002/HG003/HG004 samples

4. **Specify DRAGEN as caller** in samplesheet:
   ```csv
   caller,test_vcf_sv_caller
   dragen,dragen
   ```

5. **Match reference genome** between DRAGEN alignment and truth set (typically GRCh38)

## Troubleshooting

### Truvari refine fails
- **Check**: MAFFT is installed in the container
- **Solution**: The pipeline uses `truvari:5.3.0` which includes MAFFT

### High memory usage during refine
- **Cause**: Large number of candidate variants
- **Solution**: Adjust `--chunksize` parameter to reduce memory footprint

### Results differ from DRAGEN manual example
- **Check**: Ensure all parameters match (pctsize, pctseq, refdist, etc.)
- **Check**: Verify truth set version (v1.1 vs older versions)

## References

- DRAGEN Manual: https://help.dragen.illumina.com/product-guide/dragen-v4.4/dragen-dna-pipeline/sv-calling
- Truvari Documentation: https://github.com/ACEnglish/truvari
- NIST GIAB: https://www.nist.gov/programs-projects/genome-bottle

## Implementation Details

### New Modules

1. **`modules/local/bcftools/filter_dragen`**
   - Filters VCFs according to DRAGEN recommendations
   - Handles both truth (`ALT="*"`) and query (`<DUP:TANDEM>`) filtering

2. **`modules/nf-core/truvari/refine`**
   - Runs truvari refine on bench results
   - Outputs refined summary.json for reporting

### Modified Workflows

1. **`subworkflows/local/prepare_vcfs_test`**
   - Added DRAGEN filtering step

2. **`subworkflows/local/prepare_vcfs_truth`**
   - Added DRAGEN filtering step

3. **`subworkflows/local/truvari_benchmark`**
   - Added conditional truvari refine step
   - Uses refined summary for reporting when available
