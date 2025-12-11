#!/bin/bash

###############################################################################
# DRAGEN SV Benchmarking Test Run
# This script runs the complete DRAGEN workflow with truvari refine
###############################################################################

# ============================================================================
# STEP 1: Configure your file paths here
# ============================================================================

# Your DRAGEN SV VCF (query/test file)
DRAGEN_VCF="/path/to/your/dragen.sv.vcf.gz"

# GIAB T2T Q100 truth set files
TRUTH_VCF="/path/to/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz"
TRUTH_BED="/path/to/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed"

# Reference genome (GRCh38)
REFERENCE_FASTA="/path/to/GRCh38.fa"

# Output directory
OUTDIR="results_dragen_test_$(date +%Y%m%d_%H%M%S)"

# Sample ID (change if not HG002)
SAMPLE_ID="HG002"

# ============================================================================
# STEP 2: Validation - Check all files exist
# ============================================================================

echo "==================================================================="
echo "DRAGEN SV Benchmarking Test Run"
echo "==================================================================="
echo ""
echo "Validating input files..."
echo ""

EXIT_CODE=0

if [ ! -f "$DRAGEN_VCF" ]; then
    echo "❌ DRAGEN VCF not found: $DRAGEN_VCF"
    EXIT_CODE=1
else
    echo "✅ DRAGEN VCF: $(ls -lh $DRAGEN_VCF | awk '{print $9, "("$5")"}')"
    # Check if indexed
    if [ ! -f "${DRAGEN_VCF}.tbi" ]; then
        echo "   ⚠️  Index not found - will be created by pipeline"
    else
        echo "   ✅ Index found"
    fi
fi

if [ ! -f "$TRUTH_VCF" ]; then
    echo "❌ Truth VCF not found: $TRUTH_VCF"
    EXIT_CODE=1
else
    echo "✅ Truth VCF: $(ls -lh $TRUTH_VCF | awk '{print $9, "("$5")"}')"
    if [ ! -f "${TRUTH_VCF}.tbi" ]; then
        echo "   ⚠️  Index not found - will be created by pipeline"
    else
        echo "   ✅ Index found"
    fi
fi

if [ ! -f "$TRUTH_BED" ]; then
    echo "❌ Truth BED not found: $TRUTH_BED"
    EXIT_CODE=1
else
    echo "✅ Truth BED: $(ls -lh $TRUTH_BED | awk '{print $9, "("$5")"}')"
fi

if [ ! -f "$REFERENCE_FASTA" ]; then
    echo "❌ Reference FASTA not found: $REFERENCE_FASTA"
    EXIT_CODE=1
else
    echo "✅ Reference FASTA: $(ls -lh $REFERENCE_FASTA | awk '{print $9, "("$5")"}')"
    if [ ! -f "${REFERENCE_FASTA}.fai" ]; then
        echo "   ⚠️  FASTA index (.fai) not found - will be created by pipeline"
    else
        echo "   ✅ Index found"
    fi
fi

echo ""

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Validation failed. Please update file paths in this script."
    echo ""
    echo "Edit this file and update the paths at the top:"
    echo "  $0"
    echo ""
    exit 1
fi

echo "✅ All files validated!"
echo ""

# ============================================================================
# STEP 3: Create samplesheet
# ============================================================================

echo "Creating samplesheet..."
SAMPLESHEET="${OUTDIR}/samplesheet.csv"
mkdir -p "$OUTDIR"

cat > "$SAMPLESHEET" << EOF
id,test_vcf,caller,subsample,pctsize,pctseq,pctovl,refdist,chunksize
${SAMPLE_ID}_dragen,${DRAGEN_VCF},dragen,,0.7,0.7,0.0,2000,5000
EOF

echo "✅ Samplesheet created: $SAMPLESHEET"
echo ""
cat "$SAMPLESHEET"
echo ""

# ============================================================================
# STEP 4: Display run configuration
# ============================================================================

echo "==================================================================="
echo "Run Configuration"
echo "==================================================================="
echo ""
echo "Workflow features:"
echo "  ✅ DRAGEN-specific VCF filtering (ALT=* and <DUP:TANDEM>)"
echo "  ✅ Truvari bench (initial benchmarking)"
echo "  ✅ Truvari refine (sequence alignment refinement)"
echo "  ✅ Full nf-core reporting (plots, MultiQC, interactive tables)"
echo ""
echo "Truvari parameters (DRAGEN-recommended):"
echo "  - pctsize: 0.7 (size similarity threshold)"
echo "  - pctseq: 0.7 (sequence similarity threshold)"
echo "  - pctovl: 0.0 (overlap threshold)"
echo "  - refdist: 2000 (max breakpoint distance)"
echo "  - chunksize: 5000 (chunking for performance)"
echo ""
echo "Output directory: $OUTDIR"
echo ""

# ============================================================================
# STEP 5: Ask for confirmation
# ============================================================================

read -p "Proceed with pipeline run? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "==================================================================="
echo "Starting Pipeline"
echo "==================================================================="
echo ""

# ============================================================================
# STEP 6: Run the pipeline
# ============================================================================

nextflow run /home/user/variantbenchmarking_mygenom \
  --input "$SAMPLESHEET" \
  --genome GRCh38 \
  --fasta "$REFERENCE_FASTA" \
  --analysis germline \
  --variant_type structural \
  --method truvari \
  --test_vcf_sv_caller dragen \
  --truth_vcf "$TRUTH_VCF" \
  --truth_high_conf "$TRUTH_BED" \
  --truth_id T2TQ100 \
  --sv_standardization "svync" \
  --preprocess "filter_dragen,normalize,deduplicate" \
  --truvari_refine true \
  --outdir "$OUTDIR" \
  -profile docker \
  -resume

# ============================================================================
# STEP 7: Check results
# ============================================================================

PIPELINE_EXIT=$?

echo ""
echo "==================================================================="
if [ $PIPELINE_EXIT -eq 0 ]; then
    echo "✅ Pipeline completed successfully!"
    echo "==================================================================="
    echo ""
    echo "Results location: $OUTDIR"
    echo ""
    echo "Key outputs:"
    echo ""
    echo "📊 Main Results:"
    echo "   - Refined summary: ${OUTDIR}/structural/${SAMPLE_ID}_dragen/benchmarks/truvari/*.refined.summary.json"
    echo "   - Merged report: ${OUTDIR}/reports/truvari/merged_report.csv"
    echo "   - MultiQC dashboard: ${OUTDIR}/multiqc_report.html"
    echo ""
    echo "📁 Variant VCFs:"
    echo "   - True Positives: ${OUTDIR}/structural/${SAMPLE_ID}_dragen/benchmarks/truvari/*tp-*.vcf.gz"
    echo "   - False Positives: ${OUTDIR}/structural/${SAMPLE_ID}_dragen/benchmarks/truvari/*fp.vcf.gz"
    echo "   - False Negatives: ${OUTDIR}/structural/${SAMPLE_ID}_dragen/benchmarks/truvari/*fn.vcf.gz"
    echo ""
    echo "📈 Plots:"
    echo "   - Precision/Recall: ${OUTDIR}/reports/truvari/precision_recall.pdf"
    echo "   - SV size distribution: ${OUTDIR}/reports/truvari/sv_length_distribution.pdf"
    echo ""
    echo "Quick metrics:"
    echo "==============="

    SUMMARY_JSON=$(find "$OUTDIR" -name "*.refined.summary.json" -o -name "*summary.json" | head -1)
    if [ -f "$SUMMARY_JSON" ]; then
        echo "From: $(basename $SUMMARY_JSON)"
        echo ""
        python3 << EOF
import json
with open('$SUMMARY_JSON') as f:
    data = json.load(f)
    print(f"  TP-base:   {data.get('TP-base', 'N/A'):>8}")
    print(f"  TP-comp:   {data.get('TP-comp', 'N/A'):>8}")
    print(f"  FP:        {data.get('FP', 'N/A'):>8}")
    print(f"  FN:        {data.get('FN', 'N/A'):>8}")
    print(f"  Precision: {data.get('precision', 'N/A'):>8.4f}")
    print(f"  Recall:    {data.get('recall', 'N/A'):>8.4f}")
    print(f"  F1:        {data.get('f1', 'N/A'):>8.4f}")
EOF
    fi
    echo ""
    echo "View full report: firefox ${OUTDIR}/multiqc_report.html"
else
    echo "❌ Pipeline failed with exit code: $PIPELINE_EXIT"
    echo "==================================================================="
    echo ""
    echo "Check logs in:"
    echo "  - work/.command.log files"
    echo "  - .nextflow.log"
fi

echo ""
