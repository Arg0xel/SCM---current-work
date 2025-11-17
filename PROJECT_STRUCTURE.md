# Project Structure

## 📁 File Organization

```
webapp/
├── run_scm.R                 # Main analysis script (EXECUTABLE)
├── config.yaml               # Configuration file (OPTIONAL)
│
├── README.md                 # Main documentation and usage guide
├── INSTALLATION.md           # Installation instructions
├── VALIDATION.md             # Testing and validation guide
├── EXAMPLES.sh               # Example commands (EXECUTABLE)
├── CHANGELOG.md              # Version history
├── PROJECT_STRUCTURE.md      # This file
│
└── scm_results/              # Output directory (created by script)
    ├── tfr_path.png          # TFR trajectory plot
    ├── tfr_gap.png           # Treatment effect plot
    ├── placebo_mspe_hist.png # Placebo distribution plot
    ├── tfr_gap_in_time_placebo.png  # In-time placebo (optional)
    │
    ├── donor_weights.csv     # Donor country weights
    ├── placebo_results.csv   # Placebo test results
    ├── summary_stats.csv     # Summary statistics
    │
    └── README.txt            # Auto-generated analysis summary
```

## 📄 File Descriptions

### Core Files

#### `run_scm.R` (37 KB) ⭐
**The main analysis script** - Self-contained R implementation of Synthetic Control Method.

**What it does**:
1. Downloads World Bank data automatically
2. Cleans and prepares data with interpolation
3. Constructs donor pool based on filters
4. Fits synthetic control model
5. Runs placebo tests for inference
6. Generates publication-ready plots and tables
7. Exports results to CSV and PNG files
8. Creates auto-generated README

**How to run**:
```bash
# Basic
Rscript run_scm.R

# With options
Rscript run_scm.R --treatment_year=1981 --post_period_end=2014

# With config file
Rscript run_scm.R  # automatically reads config.yaml if present
```

**Key features**:
- 15 numbered sections with clear comments
- Extensive error handling and validation
- Progress reporting to console
- Reproducible (seed: 20231108)
- Platform-independent
- No external dependencies beyond R packages

#### `config.yaml` (4 KB)
**Configuration file** - Overrides default parameters.

**Use this to**:
- Change treatment year or time periods
- Restrict donor pool by region/income/ISO3
- Adjust data quality thresholds
- Customize placebo test settings
- Set output directory

**Format**: YAML key-value pairs with extensive comments.

**Priority**: Script defaults → config.yaml → CLI arguments

### Documentation Files

#### `README.md` (11 KB) ⭐
**Main user guide** - Comprehensive documentation.

**Contents**:
- Quick start instructions
- Feature overview
- Configuration reference table (all 25+ parameters)
- Methodology explanation
- Example use cases (9 scenarios)
- Troubleshooting guide
- References and citations

**Audience**: All users (beginners to advanced)

#### `INSTALLATION.md` (6 KB)
**Installation guide** - Platform-specific setup instructions.

**Contents**:
- R installation (Windows/macOS/Linux)
- Package installation (automatic and manual)
- Optional renv setup for reproducibility
- System requirements (minimum/recommended)
- Troubleshooting common installation issues
- Performance notes and runtime estimates

**Audience**: First-time users, system administrators

#### `VALIDATION.md` (11 KB) ⭐
**Testing and diagnostics guide** - How to verify results are valid.

**Contents**:
- Pre-run validation checklist
- Post-run quality checks (pre-fit, donor weights, etc.)
- Statistical validation (MSPE ratio, p-values)
- Robustness check examples
- Common issues and solutions
- Interpretation guidelines
- Reporting checklist for papers/presentations

**Audience**: Researchers ensuring rigor

#### `EXAMPLES.sh` (7 KB)
**Example commands** - Ready-to-use bash commands.

**Contents**:
- 28 example commands covering:
  - Basic usage
  - Time period adjustments
  - Donor pool restrictions
  - Data quality settings
  - Placebo configuration
  - Combined scenarios
  - Batch processing
- Extensive comments explaining each command
- Notes on parallel execution and logging

**Audience**: Users who prefer examples to documentation

#### `CHANGELOG.md` (9 KB)
**Version history** - What's included and what's planned.

**Contents**:
- Detailed feature list for v1.0.0
- Complete parameter reference table
- Dependency versions
- Known limitations
- Tested configurations
- Future enhancements under consideration
- Citation information

**Audience**: Developers, users tracking versions

#### `PROJECT_STRUCTURE.md` (this file)
**Project organization** - Overview of all files and workflows.

**Contents**:
- File tree with descriptions
- File size and purpose
- Usage workflows for different scenarios
- Quick reference guide
- File relationships

**Audience**: New users orienting themselves

## 🔄 Typical Workflows

### Workflow 1: Quick Analysis (5 minutes)

**Goal**: Run default analysis to see if SCM is feasible.

```bash
# 1. Ensure R is installed
R --version

# 2. Run script (installs packages automatically)
Rscript run_scm.R

# 3. Check results
ls scm_results/
cat scm_results/README.txt
```

**Expected outputs**: 
- 3-4 PNG plots
- 3 CSV files
- 1 README.txt
- Console output with key metrics

---

### Workflow 2: Custom Analysis (10 minutes)

**Goal**: Run analysis with specific donor pool and time period.

```bash
# 1. Copy and edit config template
cp config.yaml my_config.yaml
# Edit my_config.yaml in text editor

# 2. Run with custom config
mv my_config.yaml config.yaml
Rscript run_scm.R

# 3. Review results
open scm_results/tfr_path.png  # macOS
# or
xdg-open scm_results/tfr_path.png  # Linux
```

**Alternative** (without editing files):
```bash
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --post_period_end=2014 \
  --output_dir="results_regional_2014"
```

---

### Workflow 3: Sensitivity Analysis (30 minutes)

**Goal**: Test robustness to specification choices.

```bash
# Run multiple configurations
bash EXAMPLES.sh  # Runs examples 22-24

# Or manually:
Rscript run_scm.R --output_dir="results_baseline"

Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --output_dir="results_regional"

Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income,High income" \
  --output_dir="results_income"

# Compare results
echo "Baseline:"
cat results_baseline/summary_stats.csv | grep "Avg Effect"

echo "Regional:"
cat results_regional/summary_stats.csv | grep "Avg Effect"

echo "Income:"
cat results_income/summary_stats.csv | grep "Avg Effect"
```

---

### Workflow 4: Publication-Ready Analysis (1-2 hours)

**Goal**: Rigorous analysis for academic paper.

**Steps**:

1. **Read methodology** (20 min)
   ```bash
   # Read Abadie (2021) review paper
   # Review README.md and VALIDATION.md
   ```

2. **Exploratory run** (5 min)
   ```bash
   Rscript run_scm.R --output_dir="explore"
   # Check data availability, pre-fit quality
   ```

3. **Validate and diagnose** (15 min)
   ```bash
   # Use VALIDATION.md checklist
   # Check pre-RMSPE, donor weights, placebo distribution
   # Ensure in-time placebo passes
   ```

4. **Main specification** (10 min)
   ```bash
   # Based on exploration, choose final spec
   Rscript run_scm.R \
     --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
     --end_year_exclude_2015_policy_change=TRUE \
     --output_dir="results_main"
   ```

5. **Robustness checks** (30 min)
   ```bash
   # Alternative donor pools (2-3 variants)
   # Alternative time periods (pre-period, treatment year)
   # Alternative placebo filters
   # See EXAMPLES.sh lines 22-27
   ```

6. **Document and export** (15 min)
   ```bash
   # Copy key figures and tables
   # Record all specifications in notes
   # Save session info
   Rscript -e "sessionInfo()" > session_info.txt
   ```

7. **Create paper figures** (optional)
   ```r
   # Load CSVs and remake plots with custom styling
   # Combine multiple plots into panels
   # See VALIDATION.md for example code
   ```

---

### Workflow 5: Teaching/Demonstration (Live)

**Goal**: Show SCM method in class or workshop.

**Preparation**:
```bash
# Test that everything works
Rscript run_scm.R --output_dir="demo_test"
```

**Live demo** (15-20 minutes):

1. **Motivation** (3 min)
   - Show research question
   - Explain why SCM is appropriate
   
2. **Data exploration** (2 min)
   ```bash
   # Show config.yaml
   # Explain key parameters
   ```

3. **Run analysis** (5 min)
   ```bash
   # Live run with verbose output
   Rscript run_scm.R --output_dir="demo_live"
   
   # While running, explain each step:
   # - Data download
   # - Donor pool construction
   # - SCM optimization
   # - Placebo tests
   ```

4. **Interpret results** (5 min)
   ```bash
   # Open plots as they're created
   # Walk through:
   #   - Pre-treatment fit (tfr_path.png)
   #   - Treatment effect (tfr_gap.png)
   #   - Statistical significance (placebo_mspe_hist.png)
   
   # Show key numbers from console output
   ```

5. **Q&A and sensitivity** (5 min)
   ```bash
   # Demonstrate changing parameters
   Rscript run_scm.R --treatment_year=1981 --output_dir="demo_alt"
   
   # Compare results
   ```

---

## 🎯 Quick Reference

### Most Important Files

| Priority | File | Purpose |
|----------|------|---------|
| ⭐⭐⭐ | `run_scm.R` | The script - everything you need |
| ⭐⭐⭐ | `README.md` | How to use it |
| ⭐⭐ | `config.yaml` | How to customize it |
| ⭐⭐ | `VALIDATION.md` | How to verify it's working |
| ⭐ | `EXAMPLES.sh` | Pre-made commands |

### File Sizes

| File | Size | Lines | Purpose |
|------|------|-------|---------|
| run_scm.R | 37 KB | 900+ | Main script |
| README.md | 11 KB | 450+ | User guide |
| VALIDATION.md | 11 KB | 500+ | Testing guide |
| CHANGELOG.md | 9 KB | 350+ | Version history |
| EXAMPLES.sh | 7 KB | 200+ | Example commands |
| INSTALLATION.md | 6 KB | 250+ | Setup guide |
| config.yaml | 4 KB | 150+ | Configuration |
| PROJECT_STRUCTURE.md | 8 KB | 350+ | This file |

**Total**: ~93 KB of code and documentation

### Output Files (after running)

| File | Type | Size | Purpose |
|------|------|------|---------|
| tfr_path.png | PNG | ~100 KB | Main results plot |
| tfr_gap.png | PNG | ~80 KB | Treatment effect |
| placebo_mspe_hist.png | PNG | ~60 KB | Statistical test |
| donor_weights.csv | CSV | <5 KB | Donor countries |
| placebo_results.csv | CSV | 5-20 KB | Placebo tests |
| summary_stats.csv | CSV | <2 KB | Key metrics |
| README.txt | TXT | 2-3 KB | Auto-generated summary |

**Total**: ~250-300 KB per analysis run

### Command Patterns

**Basic usage**:
```bash
Rscript run_scm.R
```

**With config file**:
```bash
# Edit config.yaml, then:
Rscript run_scm.R
```

**With CLI args**:
```bash
Rscript run_scm.R --param1=value1 --param2=value2
```

**Save output to log**:
```bash
Rscript run_scm.R 2>&1 | tee analysis.log
```

**Multiple runs**:
```bash
for year in 1979 1980 1981; do
  Rscript run_scm.R --treatment_year=$year --output_dir="results_$year"
done
```

### Getting Help

1. **Quick start**: See README.md "Quick Start" section
2. **Parameters**: See README.md "Configuration Reference" table
3. **Examples**: See EXAMPLES.sh (28 commands)
4. **Troubleshooting**: See README.md "Troubleshooting" section
5. **Installation**: See INSTALLATION.md
6. **Validation**: See VALIDATION.md
7. **Methodology**: See Abadie et al. papers in README.md references

## 🔗 File Dependencies

```
run_scm.R (standalone)
    ↓ (optional)
config.yaml
    ↓ (reads)
World Bank WDI API
    ↓ (produces)
scm_results/
    ├── *.png (plots)
    ├── *.csv (data)
    └── README.txt (summary)
```

**Key point**: `run_scm.R` is completely self-contained and can run without any other files. All documentation is supplementary.

## 📊 Analysis Pipeline

```
[Configure] → [Download Data] → [Clean] → [Build Donor Pool] → 
[Fit SCM] → [Placebo Tests] → [Generate Plots] → [Export Results]
```

Each step has validation and error handling. Script reports progress at each stage.

---

**Last updated**: 2025-11-17  
**Version**: 1.0.0
