# DRAGEN SV Benchmarking Test Run

Quick start guide for running DRAGEN SV benchmarking with truvari refine.

## 🚀 Quick Start (3 steps)

### Step 1: Update File Paths

Edit the main script:
```bash
nano test_run/run_dragen_benchmark.sh
```

Update these paths at the top of the file:
```bash
DRAGEN_VCF="/path/to/your/dragen.sv.vcf.gz"
TRUTH_VCF="/path/to/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz"
TRUTH_BED="/path/to/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed"
REFERENCE_FASTA="/path/to/GRCh38.fa"
SAMPLE_ID="HG002"  # Change if different
```

### Step 2: (Optional) Verify Your DRAGEN VCF

```bash
# Update path in script
nano test_run/quick_check.sh

# Run check
./test_run/quick_check.sh
```

### Step 3: Run the Pipeline

```bash
./test_run/run_dragen_benchmark.sh
```

The script will:
- ✅ Validate all input files
- ✅ Create samplesheet automatically
- ✅ Show configuration
- ✅ Ask for confirmation
- ✅ Run complete pipeline
- ✅ Show results summary

## 📋 What You Need

### Required Files

1. **DRAGEN SV VCF** (your test file)
   - Format: `.vcf.gz` (bgzipped)
   - Should contain structural variants from DRAGEN
   - Index (`.tbi`) optional - will be created if missing

2. **GIAB T2T Q100 Truth Set** (download if needed)
   - VCF: `GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz`
   - BED: `GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed`
   - Download from: https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/analysis/NIST_HG002_T2T_Q100_v1.1/

3. **Reference Genome**
   - GRCh38 FASTA file
   - Must match the reference used for DRAGEN alignment
   - Index (`.fai`) optional - will be created if missing

### Required Software

- Docker (or Singularity/Conda)
- Nextflow
- Git (already satisfied)

## 📊 What You'll Get

### Outputs in `results_dragen_test_YYYYMMDD_HHMMSS/`

#### Main Results
```
structural/HG002_dragen/benchmarks/truvari/
├── HG002_dragen.T2TQ100.dragen.refined.summary.json  ⭐ Main metrics
├── HG002_dragen.T2TQ100.dragen.refine.log            📋 Refine log
├── HG002_dragen.T2TQ100.dragen.fn.vcf.gz             ❌ False Negatives
├── HG002_dragen.T2TQ100.dragen.fp.vcf.gz             ❌ False Positives
├── HG002_dragen.T2TQ100.dragen.tp-base.vcf.gz        ✅ TP (truth)
└── HG002_dragen.T2TQ100.dragen.tp-comp.vcf.gz        ✅ TP (DRAGEN)
```

#### Reports
```
reports/truvari/
├── merged_report.csv                    📊 Consolidated metrics
├── precision_recall.pdf                 📈 Performance plots
├── sv_length_distribution.pdf           📏 Size analysis
└── truvari_interactive_report.html      🌐 Interactive table
```

#### Overall
```
multiqc_report.html                      🎯 Complete dashboard
```

### Key Metrics Explained

From `refined.summary.json`:
- **TP-base**: True Positives from truth set (how many truth SVs were found)
- **TP-comp**: True Positives from DRAGEN (matching calls)
- **FP**: False Positives (DRAGEN calls not in truth)
- **FN**: False Negatives (truth SVs missed by DRAGEN)
- **Precision**: TP / (TP + FP) - accuracy of DRAGEN calls
- **Recall**: TP / (TP + FN) - sensitivity of DRAGEN
- **F1**: Harmonic mean of precision and recall

**Good performance targets:**
- Precision: >85%
- Recall: >75%
- F1: >80%

## 🔧 Customization

### Change Truvari Parameters

Edit `samplesheet.csv` columns:
- `pctsize`: Size similarity (0.7 = 70%)
- `pctseq`: Sequence similarity (0.7 = 70%)
- `pctovl`: Overlap threshold (0.0 = disabled)
- `refdist`: Max breakpoint distance (2000bp)
- `chunksize`: Performance tuning (5000)

### Disable Truvari Refine

In `run_dragen_benchmark.sh`, change:
```bash
--truvari_refine true
```
to:
```bash
--truvari_refine false
```

**Note**: Refine improves accuracy but takes longer (~2-3x runtime).

### Run Without DRAGEN Filters

Remove `filter_dragen` from:
```bash
--preprocess "filter_dragen,normalize,deduplicate"
```

**Not recommended** - DRAGEN filters are needed for proper benchmarking.

## 🐛 Troubleshooting

### Pipeline fails at start
**Check:**
```bash
# Verify Nextflow
nextflow -version

# Verify Docker
docker ps

# Check file permissions
ls -l /path/to/your/files
```

### "File not found" error
**Solution:**
- Use **absolute paths** (start with `/`)
- Verify files exist: `ls -lh /path/to/file`

### Memory issues
**Edit** `run_dragen_benchmark.sh` and add:
```bash
  -profile docker \
  --max_memory 32.GB \
  --max_cpus 8 \
```

### Truvari refine very slow
**Normal** - Refine uses sequence alignment (MAFFT) which is CPU-intensive.
Expected runtime: 2-4 hours for ~10k variants.

**Speed up:**
- Reduce `--chunksize` (default: 5000)
- Disable refine: `--truvari_refine false`

### Compare bench vs refine results
```bash
# Bench results (initial)
cat results*/structural/HG002*/benchmarks/truvari/*summary.json | grep -E 'precision|recall|f1'

# Refined results (final)
cat results*/structural/HG002*/benchmarks/truvari/*refined.summary.json | grep -E 'precision|recall|f1'
```

## 📖 Documentation

- **Full DRAGEN workflow**: `docs/dragen_workflow.md`
- **Pipeline usage**: `docs/usage.md`
- **Output description**: `docs/output.md`

## 🆘 Getting Help

If the pipeline fails:

1. **Check `.nextflow.log`**:
   ```bash
   tail -100 .nextflow.log
   ```

2. **Check work directory**:
   ```bash
   # Find failed process
   find work -name ".command.log" -exec ls -lt {} + | head -5

   # View last log
   cat work/XX/XXXXX/.command.log
   ```

3. **Resume from failure**:
   ```bash
   # Pipeline auto-resumes with -resume flag
   # Just re-run the same command
   ```

4. **Clean restart**:
   ```bash
   rm -rf work/
   rm -rf results*/
   ```

## ⏱️ Expected Runtime

**For ~10,000 SVs:**
- Without refine: 30-60 minutes
- With refine: 2-4 hours

**Rate limiting step:** Truvari refine (sequence alignment)

## ✅ Quick Validation

After pipeline completes:

```bash
# Check main output exists
RESULTS_DIR=$(ls -td results_dragen_test_* | head -1)

# View metrics
cat ${RESULTS_DIR}/structural/HG002_dragen/benchmarks/truvari/*.refined.summary.json

# View report
cat ${RESULTS_DIR}/reports/truvari/merged_report.csv

# Open MultiQC
firefox ${RESULTS_DIR}/multiqc_report.html
```

## 🎓 Next Steps

1. **Analyze results** - Check precision, recall, F1
2. **Inspect variants** - Review FP/FN VCFs to understand errors
3. **Compare to benchmarks** - How does your DRAGEN version perform?
4. **Optimize parameters** - Try different pctsize/pctseq values
5. **Production runs** - Scale to multiple samples

---

**Ready to start?** → `./test_run/run_dragen_benchmark.sh`
