# Validation and Testing Guide

This document describes how to validate the Synthetic Control analysis and interpret results.

## 🔍 Pre-Run Validation

### 1. Configuration Check

Before running, verify your configuration makes sense:

```r
# In R console
source("run_scm.R", echo = TRUE, max.deparse.length = 100)
# This will print the final configuration
```

**Check**:
- Treatment year is within your time range
- Pre-period ends before treatment year
- Post-period starts at treatment year
- At least 10-15 years in pre-period (recommended)

### 2. Data Availability Check

**Outcome variable (TFR)**:
- World Bank code: `SP.DYN.TFRT.IN`
- Good coverage: 1960-present for most countries
- May have gaps for: conflict zones, very small countries

**Predictor variables (defaults)**:
- GDP per capita: `NY.GDP.PCAP.KD` (1960+, good coverage)
- Life expectancy: `SP.DYN.LE00.IN` (1960+, excellent coverage)
- Urbanization: `SP.URB.TOTL.IN.ZS` (1960+, good coverage)

**Tip**: If analysis fails due to missing data, try:
1. Enabling interpolation
2. Reducing `min_pre_coverage` to 0.7
3. Shortening pre-period to 1965-1979
4. Using fewer/different predictors

## ✅ Post-Run Validation

### 1. Data Quality Checks

**A. Pre-treatment fit quality**

```r
# Check pre-RMSPE in summary_stats.csv or console output
# Good fit: pre-RMSPE < 0.5 for TFR
# Acceptable: pre-RMSPE < 1.0
# Poor fit: pre-RMSPE > 1.0 (interpretation difficult)
```

**Visual check**: In `tfr_path.png`, synthetic China should closely track actual China before 1980.

**B. Donor pool size**

```r
# Check N Donors in summary_stats.csv
# Minimum: 5 donors (required)
# Good: 20-50 donors
# Large: 50+ donors
```

Too few donors → synthetic control may not balance well  
Too many donors → may include poor matches

**C. Donor weights concentration**

```r
# Check donor_weights.csv
# Look for:
# - How many donors have weight > 5%?
# - Is one donor > 50%? (concerning - sensitivity to that country)
# - Are top 3 donors > 90%? (concerning - limited pooling)
```

**Ideal**: Weights spread across 5-10 donors, no single donor > 30%

**D. Predictor balance**

```r
# Synth package prints predictor balance table
# Check that treated and synthetic have similar values
# Large differences suggest poor match
```

### 2. Results Validation

**A. Gap plot coherence** (`tfr_gap.png`)

✅ **Good pattern**:
- Small, noisy gaps in pre-period (close to zero)
- Clear, sustained shift in post-period
- Smooth trajectory (not erratic jumps)

⚠️ **Suspicious pattern**:
- Large gaps in pre-period → poor fit
- Gap reverses direction multiple times → confounding?
- Gap appears before treatment → violation of parallel trends

**B. In-time placebo test** (`tfr_gap_in_time_placebo.png`)

✅ **Pass**: 
- No systematic gap at fake treatment year
- Gap remains close to zero until real treatment

⚠️ **Fail**:
- Large gap at fake treatment year
- Suggests pre-trends or model misspecification

**C. Placebo distribution** (`placebo_mspe_hist.png`)

✅ **Significant result**:
- China's ratio is in far right tail (top 5-10%)
- p-value < 0.05 or 0.10
- Few placebos exceed China's ratio

⚠️ **Non-significant**:
- China's ratio is in middle of distribution
- p-value > 0.10
- Many placebos have similar or larger ratios

### 3. Statistical Validation

**MSPE Ratio Interpretation**:
```
Ratio < 2:   Effect might not be distinguishable from noise
Ratio 2-5:   Moderate effect (check p-value)
Ratio 5-10:  Strong effect, likely significant
Ratio > 10:  Very strong effect (check for poor pre-fit)
```

**P-value Interpretation**:
```
p < 0.05:  Statistically significant (5% level)
p < 0.10:  Marginally significant (10% level)
p < 0.20:  Suggestive evidence
p > 0.20:  Not significant (could be chance)
```

**Note**: SCM p-values are approximate. With 20 donors → minimum p-value = 1/20 = 0.05

### 4. Robustness Checks

Run multiple specifications to test sensitivity:

**A. Donor pool variations**:
```bash
# Baseline
Rscript run_scm.R --output_dir="robust_baseline"

# Regional restriction
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --output_dir="robust_regional"

# Income restriction
Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income,High income" \
  --output_dir="robust_income"
```

**Expected**: Similar average effects (±20%) and significance across specifications

**B. Time period variations**:
```bash
# Longer pre-period
Rscript run_scm.R --pre_period=1960,1979 --output_dir="robust_long_pre"

# Shorter pre-period
Rscript run_scm.R --pre_period=1970,1979 --output_dir="robust_short_pre"

# Exclude 2015
Rscript run_scm.R --post_period_end=2014 --output_dir="robust_excl_2015"
```

**Expected**: Similar pre-treatment fit and post-treatment trajectory

**C. Treatment timing**:
```bash
# Alternative treatment years (policy rolled out gradually)
Rscript run_scm.R --treatment_year=1979 --output_dir="robust_1979"
Rscript run_scm.R --treatment_year=1981 --output_dir="robust_1981"
```

**Expected**: Similar overall effect magnitude

### 5. Common Issues and Diagnostics

#### Issue: Pre-RMSPE > 1.0

**Diagnosis**: Poor pre-treatment fit

**Possible causes**:
- Limited donor pool (not enough good matches)
- China's pre-trend differs from all donors
- Missing data / interpolation issues
- Wrong predictors

**Solutions**:
1. Expand donor pool (relax filters)
2. Add more predictors or different time points
3. Check for data quality issues
4. Consider: Is China suitable for SCM? (needs good comparison units)

#### Issue: Very high MSPE ratio (>20) with significant p-value

**Diagnosis**: Either very strong effect OR very poor pre-fit

**Check**:
1. Look at pre-RMSPE (should be < 0.5)
2. Visual inspection of pre-treatment fit
3. If pre-fit is poor, results are unreliable

**Interpretation**: 
- If pre-fit is good: Strong evidence of large effect
- If pre-fit is poor: Cannot interpret

#### Issue: Large pre-treatment gaps

**Diagnosis**: Synthetic control doesn't match China before treatment

**Implications**: 
- Post-treatment differences may not be causal
- Parallel trends assumption likely violated

**Solutions**:
1. Try different predictor years
2. Expand/change donor pool
3. Consider alternative methods (diff-in-diff, etc.)

#### Issue: Non-significant p-value despite large gap

**Diagnosis**: High variance in placebo tests

**Possible causes**:
- Small donor pool (few placebos, low power)
- Volatile data (many countries have large swings)
- Poor fits across many placebos

**Solutions**:
1. Check `placebo_results.csv` for poor fits
2. Adjust `placebo_prefit_filter_value`
3. Interpret substantive magnitude alongside significance

#### Issue: One donor has >50% weight

**Diagnosis**: Synthetic control overly dependent on one country

**Implications**:
- Results sensitive to that donor's idiosyncrasies
- Limited pooling → less robust

**Solutions**:
1. Check which donor (is it a good match?)
2. Try excluding that donor and rerun
3. Report as robustness check

### 6. Reporting Checklist

When presenting results, include:

✅ **Methods**:
- [ ] Treatment unit and year clearly stated
- [ ] Pre/post periods specified
- [ ] Donor pool construction described (filters applied)
- [ ] Predictors listed
- [ ] Data source cited (World Bank WDI)

✅ **Results**:
- [ ] Pre-treatment fit quality (RMSPE, visual)
- [ ] Average treatment effect with units
- [ ] MSPE ratio reported
- [ ] Placebo p-value reported
- [ ] Number of placebos stated

✅ **Visuals**:
- [ ] Path plot showing treated vs synthetic
- [ ] Gap plot showing treatment effect over time
- [ ] Placebo distribution plot (if significant)

✅ **Robustness**:
- [ ] At least one alternative donor pool
- [ ] At least one alternative time specification
- [ ] Discussion of sensitivity

✅ **Limitations**:
- [ ] Acknowledge assumption of no spillovers
- [ ] Note interpolation if used
- [ ] Discuss donor pool representativeness
- [ ] Mention any poor pre-fit issues

## 📊 Interpreting Specific Results

### Expected Results for China One-Child Policy

**Based on existing literature**:

1. **Pre-treatment fit**: Should be good (RMSPE < 0.5)
   - China's TFR decline began in 1970s (before policy)
   - May be harder to match than commonly assumed

2. **Effect magnitude**: Moderate to large negative
   - Expected reduction: 0.3-1.0 births per woman
   - Total effect depends on counterfactual trajectory

3. **Statistical significance**: Likely significant
   - Policy was major intervention
   - But: declining TFR globally in this period

4. **Sensitive to**:
   - Donor pool choice (East Asian vs global donors)
   - Treatment timing (policy rollout was gradual)
   - Predictor choice (economic development matters)

### Comparison to Literature

**Key papers** (for context):
- Wang (2017): Estimated 0.3-0.5 reduction using DID
- Goodkind (2017): Found effect diminished over time
- Whyte et al. (2015): Questioned necessity of policy

**This SCM approach**:
- Provides complementary evidence
- More flexible counterfactual than DID
- But requires good donor pool

## 🔧 Advanced Diagnostics (Optional)

### Custom Diagnostic Script

```r
# Read results and perform additional checks
library(readr)
library(dplyr)

# Load results
weights <- read_csv("scm_results/donor_weights.csv")
placebos <- read_csv("scm_results/placebo_results.csv")
summary <- read_csv("scm_results/summary_stats.csv")

# Check weight concentration (Herfindahl index)
hhi <- sum(weights$Weight^2)
cat(sprintf("Weight concentration (HHI): %.3f\n", hhi))
cat(ifelse(hhi > 0.25, "Warning: Concentrated weights\n", "OK: Dispersed weights\n"))

# Check effective number of donors
eff_n <- 1 / sum(weights$Weight^2)
cat(sprintf("Effective number of donors: %.1f\n", eff_n))

# Compare China's ratio to placebo distribution
china_ratio <- as.numeric(summary$Value[summary$Metric == "MSPE Ratio"])
placebo_ratios <- placebos$mspe_ratio
rank <- sum(placebo_ratios >= china_ratio)
percentile <- rank / length(placebo_ratios)

cat(sprintf("\nChina's ratio: %.3f\n", china_ratio))
cat(sprintf("Percentile: %.1f%% (rank %d of %d)\n", 
            (1-percentile)*100, rank, length(placebo_ratios)))
```

## 📚 Further Reading

- **Abadie (2021)** "Using Synthetic Controls" - comprehensive guide
- **Ferman & Pinto (2021)** "Inference in Differences-in-Differences with Few Treated Units"
- **Arkhangelsky et al. (2021)** "Synthetic Difference-in-Differences"

## ✉️ Getting Help

If validation reveals problems:

1. **Data issues**: Try alternative time periods or predictors
2. **Poor fit**: Expand donor pool or consider alternative methods
3. **Methodological questions**: Consult Abadie (2021) review
4. **Interpretation**: Compare to existing literature on China's policy

Remember: **SCM is only valid if pre-treatment fit is good and assumptions are met.**
