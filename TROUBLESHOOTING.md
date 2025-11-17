# Troubleshooting Guide

Common issues and their solutions when running the Synthetic Control analysis.

## 🚨 Critical: How to Run the Script

### ✅ CORRECT Way (Command Line)

```bash
# Navigate to the directory containing run_scm.R
cd /path/to/webapp

# Run with Rscript
Rscript run_scm.R
```

### ❌ INCORRECT Way (Interactive R Session)

**DO NOT DO THIS:**
```r
# In R console - DON'T DO THIS!
source("run_scm.R")

# Or copy-pasting the entire script into R console
```

**Why?** The script is designed for batch execution. Running interactively can cause:
- WDI download to hang
- Package installation prompts that block execution
- Incorrect progress reporting
- Memory issues

---

## 📊 Issue: WDI Download Hangs or Times Out

### Symptoms
- Script gets stuck at "Downloading data from World Bank WDI..."
- No progress for several minutes
- Process appears frozen

### Solutions

#### 1. Run from Command Line (Most Important!)
```bash
# Exit R if running interactively
q()

# Run from terminal/command prompt
Rscript run_scm.R
```

#### 2. Check Internet Connection
```bash
# Test World Bank API access
curl https://api.worldbank.org/v2/country

# Or in browser, visit:
# https://api.worldbank.org/v2/country
```

#### 3. Try with Shorter Time Period
```bash
# If 1960-2015 is too much data
Rscript run_scm.R --pre_period=1970,1979 --post_period_end=2014
```

#### 4. Retry with Explicit Timeout
In R (if you must run interactively):
```r
# Set timeout (in seconds)
options(timeout = 300)  # 5 minutes

# Then source
source("run_scm.R")
```

#### 5. Check World Bank API Status
- Visit: https://datahelpdesk.worldbank.org/
- Check for service announcements
- API may be temporarily unavailable

#### 6. Use Local WDI Cache (Advanced)
```r
# First download in interactive session
library(WDI)
WDIcache()  # Downloads and caches all WDI metadata

# Then run script
Rscript run_scm.R
```

---

## 📦 Issue: Package Installation Hangs

### Symptoms
- Script stops during "Installing and loading required packages..."
- Waiting for user input that never comes

### Solutions

#### 1. Pre-install Packages
```r
# In interactive R session, install everything first:
install.packages(c("Synth", "WDI", "dplyr", "tidyr", "readr", 
                   "ggplot2", "countrycode", "zoo", "scales"),
                 dependencies = TRUE)

# Then run script from command line
```

#### 2. Run with Quiet Mode
```bash
Rscript run_scm.R > output.log 2>&1
# Check output.log for progress
```

---

## 🔴 Issue: Interactive Session Warning

### Message
```
*** WARNING: You are running this script interactively! ***
This script is designed to be run from command line with:
  Rscript run_scm.R
```

### Solution
This is intentional! The script detects interactive execution and warns you.

**Best practice:**
1. Exit R: `q()`
2. Run from terminal: `Rscript run_scm.R`

**If you must continue interactively:**
- Wait for the 5-second countdown
- Be prepared for potential hangs
- Have Task Manager/Activity Monitor ready to kill process if needed

---

## 💾 Issue: Insufficient Memory

### Symptoms
- "Cannot allocate vector of size..." error
- R session crashes during placebo tests
- System becomes very slow

### Solutions

#### 1. Limit Number of Placebos
```bash
Rscript run_scm.R --placebo_max_n=20
```

#### 2. Restrict Donor Pool
```bash
# Smaller donor pool = less memory
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific" \
  --placebo_max_n=30
```

#### 3. Close Other Programs
- Free up RAM by closing browsers, applications
- Check Task Manager/Activity Monitor

#### 4. Increase R Memory Limit (Windows)
```r
# Before running script
memory.limit(size = 8000)  # 8 GB
```

---

## 📁 Issue: Permission Denied / Cannot Write

### Symptoms
- "Cannot create directory 'scm_results'"
- "Permission denied" when saving files

### Solutions

#### 1. Check Write Permissions
```bash
# Check current directory
ls -la

# Ensure you can write
touch test.txt
rm test.txt
```

#### 2. Run from Different Directory
```bash
# Navigate to a directory where you have write permissions
cd ~/Documents
Rscript /path/to/run_scm.R
```

#### 3. Specify Custom Output Directory
```bash
Rscript run_scm.R --output_dir="$HOME/analysis_results"
```

#### 4. Run with Elevated Permissions (Last Resort)
```bash
# macOS/Linux
sudo Rscript run_scm.R

# Not recommended - better to fix permissions
```

---

## 🌐 Issue: World Bank API Errors

### Message
```
Error in WDI: Invalid indicator code
```

### Solutions

#### 1. Verify Indicator Codes
Current defaults:
- `SP.DYN.TFRT.IN` (Total Fertility Rate) ✓
- `NY.GDP.PCAP.KD` (GDP per capita) ✓
- `SP.DYN.LE00.IN` (Life expectancy) ✓
- `SP.URB.TOTL.IN.ZS` (Urbanization) ✓

Check codes at: https://data.worldbank.org/indicator

#### 2. Test Individual Indicators
```r
library(WDI)

# Test each indicator
WDI(indicator = "SP.DYN.TFRT.IN", start = 2010, end = 2015)
WDI(indicator = "NY.GDP.PCAP.KD", start = 2010, end = 2015)
```

#### 3. Use Alternative Predictors
```bash
# If one predictor fails, remove it
Rscript run_scm.R \
  --predictors_wdi_codes="NY.GDP.PCAP.KD,SP.DYN.LE00.IN"
```

---

## 📉 Issue: "China has insufficient outcome coverage"

### Symptoms
```
Error: China has insufficient outcome coverage (XX% < 80% required)
```

### Solutions

#### 1. Enable Interpolation
```bash
Rscript run_scm.R \
  --interpolate_small_gaps=TRUE \
  --max_gap_to_interpolate=5
```

#### 2. Reduce Coverage Requirement
```bash
Rscript run_scm.R --min_pre_coverage=0.7
```

#### 3. Shorten Pre-Period
```bash
# Start from 1970 instead of 1960
Rscript run_scm.R --pre_period=1970,1979
```

#### 4. Check Data Availability
```r
library(WDI)
library(dplyr)

# Check China's TFR coverage
china_tfr <- WDI(country = "CHN", 
                 indicator = "SP.DYN.TFRT.IN",
                 start = 1960, end = 2015)

china_tfr %>%
  filter(!is.na(SP.DYN.TFRT.IN)) %>%
  nrow()  # Count non-missing years
```

---

## 🔧 Issue: Synth Optimization Fails

### Symptoms
```
Error in synth(): Optimization failed to converge
```

### Solutions

#### 1. Expand Donor Pool
```bash
# Remove some filters
Rscript run_scm.R \
  --remove_microstates_by_name=FALSE \
  --min_pre_coverage=0.7
```

#### 2. Simplify Predictors
```bash
# Use fewer predictors
Rscript run_scm.R \
  --predictors_wdi_codes="NY.GDP.PCAP.KD,SP.DYN.LE00.IN"
```

#### 3. Check Data Quality
Look for:
- Too many NA values
- Very small donor pool (< 10 countries)
- Incompatible constraints

---

## 🐌 Issue: Script Runs Very Slowly

### Expected Runtime
- First run: 3-5 minutes (with package install)
- Subsequent runs: 5-15 minutes
- With 100+ donors: 15-30 minutes

### If Slower Than Expected

#### 1. Limit Placebos
```bash
Rscript run_scm.R --placebo_max_n=30
```

#### 2. Use Fewer Donors
```bash
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific"
```

#### 3. Monitor Progress
```bash
# Run with output to see progress
Rscript run_scm.R 2>&1 | tee analysis.log

# In another terminal, watch the log
tail -f analysis.log
```

#### 4. Check System Resources
```bash
# macOS/Linux
top

# Look for R process CPU/memory usage
```

---

## 🖥️ Platform-Specific Issues

### macOS

#### Issue: "Cannot load package X"
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install from Homebrew
brew install r
```

#### Issue: SSL/TLS Errors
```bash
# Update certificates
brew install openssl
```

### Windows

#### Issue: Path with Spaces
```bash
# Use quotes
Rscript "C:\Users\My Name\Documents\run_scm.R"
```

#### Issue: Rscript Not Found
```bash
# Add R to PATH or use full path
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" run_scm.R
```

### Linux

#### Issue: Missing System Libraries
```bash
# Ubuntu/Debian
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev

# CentOS/RHEL
sudo yum install libcurl-devel openssl-devel libxml2-devel
```

---

## 🔍 Debugging Steps

### 1. Test R Installation
```bash
R --version
Rscript --version
```

### 2. Test Internet Connection
```bash
ping api.worldbank.org
```

### 3. Test Package Loading
```r
# In R console
library(Synth)
library(WDI)
library(dplyr)
# If any fail, reinstall
```

### 4. Test WDI Download
```r
# Minimal test
library(WDI)
test <- WDI(country = "CHN", indicator = "SP.DYN.TFRT.IN", 
            start = 2010, end = 2015)
print(test)
```

### 5. Run with Verbose Output
```bash
# Capture all output
Rscript run_scm.R > full_output.log 2>&1

# Check for errors
cat full_output.log
```

---

## 🆘 Getting Additional Help

### 1. Check Documentation
- `README.md` - Comprehensive guide
- `QUICKSTART.md` - Fast start
- `VALIDATION.md` - Result checking
- `INSTALLATION.md` - Setup help

### 2. Check Your Configuration
```bash
# Print current config
Rscript run_scm.R --help  # (if implemented)

# Or check config.yaml
cat config.yaml
```

### 3. Simplify to Minimal Example
```bash
# Absolute minimum configuration
Rscript run_scm.R \
  --pre_period=1970,1979 \
  --post_period_end=2000 \
  --placebo_max_n=10 \
  --donor_include_regions="East Asia & Pacific"
```

### 4. Session Info
If asking for help, include:
```r
sessionInfo()
# Copy and paste the output
```

---

## ✅ Prevention Checklist

Before running, verify:

- [ ] R version 4.0+ installed
- [ ] Running from **command line** (not interactively)
- [ ] Internet connection active
- [ ] Write permissions in current directory
- [ ] Sufficient RAM (4+ GB free)
- [ ] Sufficient disk space (1+ GB free)

---

## 🔗 Quick Reference

| Problem | Quick Fix |
|---------|-----------|
| Script hangs at WDI download | Exit R, run `Rscript run_scm.R` from terminal |
| Package install hangs | Pre-install packages, then run script |
| Insufficient coverage | `--interpolate_small_gaps=TRUE --max_gap_to_interpolate=5` |
| Small donor pool | `--min_pre_coverage=0.7 --remove_microstates_by_name=FALSE` |
| Too slow | `--placebo_max_n=20` |
| Memory error | `--placebo_max_n=20 --donor_include_regions="East Asia & Pacific"` |
| Permission denied | Run from home directory or use `--output_dir=~/results` |

---

**Last Updated**: 2025-11-17  
**Version**: 1.0.0

For more help, see `README.md` or `INDEX.md`.
