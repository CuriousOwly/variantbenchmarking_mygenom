#!/bin/bash

###############################################################################
# Quick VCF File Checker
# Run this first to verify your DRAGEN VCF is properly formatted
###############################################################################

echo "==================================================================="
echo "DRAGEN VCF Quick Check"
echo "==================================================================="
echo ""

# Update this path
VCF="/path/to/your/dragen.sv.vcf.gz"

if [ ! -f "$VCF" ]; then
    echo "❌ File not found: $VCF"
    echo ""
    echo "Please update the VCF path in this script:"
    echo "  nano $0"
    exit 1
fi

echo "File: $VCF"
echo "Size: $(ls -lh $VCF | awk '{print $5}')"
echo ""

# Check if bgzipped
echo "Checking compression..."
if file "$VCF" | grep -q "gzip compressed"; then
    echo "✅ File is gzip compressed"
else
    echo "❌ File must be bgzipped (.vcf.gz)"
    exit 1
fi

# Check if indexed
if [ -f "${VCF}.tbi" ]; then
    echo "✅ Index file exists (${VCF}.tbi)"
else
    echo "⚠️  Index file not found - pipeline will create it"
fi

echo ""
echo "Checking VCF header..."
zcat "$VCF" | head -1000 | grep "^#" | tail -20

echo ""
echo "Sample line count:"
zcat "$VCF" | grep -v "^#" | head -5

VARIANT_COUNT=$(zcat "$VCF" | grep -vc "^#")
echo ""
echo "Total variants: $VARIANT_COUNT"

echo ""
echo "Checking for DRAGEN-specific fields..."
HAS_DUP_TANDEM=$(zcat "$VCF" | grep -v "^#" | grep -c "<DUP:TANDEM>" || true)
echo "  <DUP:TANDEM> records: $HAS_DUP_TANDEM"
if [ $HAS_DUP_TANDEM -gt 0 ]; then
    echo "  ✅ Will be filtered by pipeline (--preprocess filter_dragen)"
fi

echo ""
echo "Sample name(s) in VCF:"
zcat "$VCF" | grep "^#CHROM" | cut -f10-

echo ""
echo "==================================================================="
echo "✅ VCF looks good! Ready to run pipeline."
echo "==================================================================="
echo ""
echo "Next step: Edit and run the benchmark script"
echo "  1. nano test_run/run_dragen_benchmark.sh"
echo "  2. Update file paths at the top"
echo "  3. ./test_run/run_dragen_benchmark.sh"
