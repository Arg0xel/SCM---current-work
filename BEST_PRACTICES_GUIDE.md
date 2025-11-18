# SCM Best Practices Implementation Guide

**Marker: "2"**  
**Date**: 2025-11-17 18:15 UTC  
**For**: Senior Data Scientists & SCM Practitioners

---

## Purpose

This guide explains **when and how** to apply each SCM best practice, with specific implementation guidance for the China One-Child Policy analysis.

---

## Quick Decision Matrix

| Your Situation | Use | Rationale |
|----------------|-----|-----------|
| **Production analysis, proven methodology** | `run_scm.R` (V1) | ✅ Fixed core bug, production-ready |
| **Small donor pool (<20), need validation** | `run_scm_v2.R` | ✅ Stricter checks, better diagnostics |
| **High-stakes analysis (publication, policy)** | V2 + Full enhancements | ✅ Maximum robustness, transparency |
| **Exploratory analysis, quick results** | `run_scm.R` with defaults | ✅ Fast, reliable |
| **Sensitive to assumptions** | V2 + Sensitivity analysis | ✅ Documents robustness |
| **Unusual donors (wars, shocks)** | V2 + Shock detection | ✅ Validates counterfactual |

---

## Best Practice 1: Pre-Treatment Period Validation

### Why It Matters
Using post-treatment outcomes for matching constitutes **data leakage** - you're fitting the model using information about the treatment effect itself.

### When to Apply
✅ **ALWAYS** - This is non-negotiable

### Implementation (V2)
```r
# Automatic validation in run_scm_v2.R
invalid_years <- config$special_predictor_years[
  config$special_predictor_years >= config$treatment_year
]
if (length(invalid_years) > 0) {
  stop("ERROR: Special predictor years must be < treatment year!")
}
```

### How to Fix Violations
```bash
# WRONG: Uses outcome from treatment year
Rscript run_scm.R --special_predictor_years=1965,1970,1975,1980

# RIGHT: Only pre-treatment years
Rscript run_scm.R --special_predictor_years=1965,1970,1975,1979
```

### Methodological Impact
- ❌ Without: Results are **methodologically invalid** (circular reasoning)
- ✅ With: Results are **credible** (no information leakage)

---

## Best Practice 2: Minimum Donor Pool Size

### Why It Matters
SCM constructs a **convex combination** of donors. With too few donors:
- Can't span the "convex hull" of possible trajectories
- Over-reliance on 1-2 countries (essentially single comparison)
- False positives increase dramatically (Ferman & Pinto, 2019)

### When to Apply
✅ **Always require ≥10 donors** (20-50+ ideal)

### Implementation (V2)
```r
# Automatic enforcement in run_scm_v2.R
if (length(donor_pool) < config$min_donor_pool_size) {
  stop("ERROR: Only %d donors (need ≥%d)", length(donor_pool), config$min_donor_pool_size)
}
```

### Thresholds
| Donor Count | Assessment | Action |
|-------------|------------|--------|
| < 5 | ❌ Invalid | Reject analysis, relax filters |
| 5-9 | ⚠️ Questionable | Use with extreme caution, document |
| 10-19 | ⚠️ Marginal | Acceptable but test sensitivity |
| 20-49 | ✅ Good | Standard for publication |
| 50+ | ✅✅ Excellent | Ideal for robust inference |

### How to Increase Donor Pool
```bash
# Option 1: Lower coverage (more donors, possibly lower quality)
Rscript run_scm_v2.R --min_pre_coverage=0.7

# Option 2: Fewer predictors required
Rscript run_scm_v2.R --min_predictors_ok=1

# Option 3: Enable interpolation (fill data gaps)
Rscript run_scm_v2.R --interpolate_small_gaps=TRUE --max_gap_to_interpolate=5

# Option 4: Shorter pre-period (better data quality)
Rscript run_scm_v2.R --pre_period=1970,1979

# Option 5: Combine approaches
Rscript run_scm_v2.R --min_pre_coverage=0.7 --min_predictors_ok=1 --pre_period=1970,1979
```

### Trade-offs
| Approach | Pros | Cons |
|----------|------|------|
| Lower coverage | ✅ More donors | ❌ Lower data quality |
| Fewer predictors | ✅ More donors | ❌ Less matching information |
| Interpolation | ✅ Fills gaps | ❌ Synthetic data introduced |
| Shorter period | ✅ Better data | ❌ Less pre-treatment info |

### Methodological Impact
- ❌ 2 donors: Results are **meaningless** (just 1-country comparison)
- ⚠️ 5-9 donors: Results are **questionable** (report with heavy caveats)
- ✅ 20+ donors: Results are **credible** (standard for publication)
- ✅✅ 50+ donors: Results are **highly robust** (gold standard)

---

## Best Practice 3: Cross-Validation for Predictor Weights

### Why It Matters
Synth assigns weights to predictors (V-weights) by minimizing pre-treatment RMSPE. This can **overfit** to pre-treatment noise, yielding good in-sample fit but poor out-of-sample prediction.

### When to Apply
✅ When you have long pre-period (≥15 years)  
⚠️ Optional for short pre-periods (<15 years)

### Implementation (Pseudocode)
```r
# 5-fold time-series cross-validation
n_folds <- 5
pre_years <- config$pre_period[1]:config$pre_period[2]
fold_size <- ceiling(length(pre_years) / n_folds)

cv_errors <- numeric(n_folds)

for (k in 1:n_folds) {
  # Hold out k-th fold
  holdout_idx <- ((k-1)*fold_size + 1):min(k*fold_size, length(pre_years))
  holdout_years <- pre_years[holdout_idx]
  training_years <- setdiff(pre_years, holdout_years)
  
  # Fit on training years only
  cv_dataprep <- dataprep(..., time.optimize.ssr = training_years)
  cv_synth <- synth(cv_dataprep)
  
  # Predict holdout years
  cv_predictions <- cv_dataprep$Y0plot[as.character(holdout_years), ] %*% cv_synth$solution.w
  cv_actual <- cv_dataprep$Y1plot[as.character(holdout_years), ]
  cv_errors[k] <- sqrt(mean((cv_actual - cv_predictions)^2))
}

# Compare to full model
cv_rmspe <- mean(cv_errors)
if (cv_rmspe > pre_rmspe * 1.2) {
  warning("Possible overfitting: CV RMSPE %.3f vs full RMSPE %.3f", 
          cv_rmspe, pre_rmspe)
}
```

### Interpretation
```
Full model RMSPE: 0.215
CV RMSPE: 0.247

✓ CV error only 15% worse than full model
✓ No evidence of overfitting
```

### When to Worry
- ❌ CV RMSPE > 1.5× full RMSPE: Serious overfitting
- ⚠️ CV RMSPE > 1.2× full RMSPE: Mild overfitting
- ✅ CV RMSPE < 1.2× full RMSPE: Good generalization

### Methodological Impact
- ❌ Without: May report artificially good fit (overfitted)
- ✅ With: Confidence that fit is genuine (not overfitted)

---

## Best Practice 4: Fixed Placebo Pre-Fit Filter

### Why It Matters
**Current bug**: When computing placebo pre-fit threshold (e.g., 90th percentile), the script **may include China** in the calculation, biasing the cutoff.

**Correct procedure** (Abadie et al., 2010):
1. Compute threshold using **only donors** (exclude treated unit)
2. Filter donors with poor pre-fits
3. Then compute p-value including treated unit

### When to Apply
✅ **Always** when using placebo pre-fit filter

### Implementation
```r
# WRONG (current in V1):
threshold <- quantile(placebo_df$pre_rmspe, 0.9)  # May include China
placebo_df_filtered <- placebo_df %>% filter(pre_rmspe <= threshold)
p_value <- mean(placebo_df_filtered$mspe_ratio >= china_mspe_ratio)

# RIGHT (V2 fix):
# Step 1: Exclude China from threshold calculation
placebo_df_no_treated <- placebo_df %>% filter(iso3c != config$treatment_country_iso3)
threshold <- quantile(placebo_df_no_treated$pre_rmspe, 0.9)

# Step 2: Filter donors only
placebo_df_filtered <- placebo_df_no_treated %>% filter(pre_rmspe <= threshold)

# Step 3: Compute p-value including China
all_units <- bind_rows(
  data.frame(iso3c = config$treatment_country_iso3, 
             mspe_ratio = china_mspe_ratio,
             pre_rmspe = pre_rmspe),
  placebo_df_filtered
)
p_value <- mean(all_units$mspe_ratio >= china_mspe_ratio)
```

### Impact Example
```
WRONG method:
  Threshold: 0.42 (90th percentile including China with 0.21)
  Removed: 5 donors
  P-value: 0.089

RIGHT method:
  Threshold: 0.39 (90th percentile excluding China)
  Removed: 6 donors  
  P-value: 0.073

Difference: P-value 20% smaller (more conservative)
```

### Methodological Impact
- ❌ Without: P-value may be **upward biased** (less conservative)
- ✅ With: P-value is **unbiased** (correct inference)

---

## Best Practice 5: Automated Sensitivity Analysis

### Why It Matters
Single specification may be **sensitive to arbitrary choices** (coverage threshold, pre-period, predictor set). Sensitivity analysis documents **robustness**.

### When to Apply
✅ **Always** for publication  
✅ When reviewer asks "how robust are your results?"  
⚠️ Optional for exploratory analysis

### What to Vary
1. **Coverage threshold**: 0.6, 0.7, 0.75, 0.8, 0.85
2. **Pre-period length**: 1960-79, 1965-79, 1970-79
3. **Predictor set**: All 3, drop GDP, drop each predictor
4. **Special predictor years**: Include/exclude early years (1960s)
5. **Donor pool**: All regions, Asia+LatAm only, middle-income only

### Implementation
```bash
# Run sensitivity analysis
for threshold in 0.7 0.75 0.8 0.85; do
  Rscript run_scm.R --min_pre_coverage=$threshold \
    --output_dir="scm_results_cov${threshold/./}"
done

# Compare results
Rscript compare_sensitivity.R scm_results_cov*
```

### Reporting
```
Sensitivity Analysis: Coverage Threshold

Spec     Coverage  N_Donors  Pre_RMSPE  Effect    P-value
Main     80%       48        0.215      -0.452    0.073
Robust1  75%       58        0.206      -0.463    0.068
Robust2  70%       67        0.198      -0.471    0.052
Robust3  85%       35        0.237      -0.438    0.095

Conclusion:
  ✓ Effect stable: -0.44 to -0.47 (range: 0.03)
  ✓ Always negative and substantial
  ✓ P-value ranges 0.05-0.10 (consistently significant)
  ✓ Results robust to coverage threshold choice
```

### What to Report
- **Effect range**: Min and max across specifications
- **Sign stability**: Does effect ever flip sign?
- **Significance consistency**: P-value range
- **Preferred spec**: Main result + rationale
- **Outliers**: Note any unusual specifications

### Methodological Impact
- ❌ Without: Reviewer skepticism ("cherry-picked specification?")
- ✅ With: Increased confidence ("robust across choices")

---

## Best Practice 6: Leave-One-Out Diagnostics

### Why It Matters
If removing a single donor **dramatically changes** the result, the finding is **fragile** and driven by that specific country.

### When to Apply
✅ When top donor has weight > 30%  
✅ Always for publication  
⚠️ Optional if weights are highly dispersed (<20% each)

### Implementation
```r
# Test influence of top 5 donors
top_donors <- donor_weights %>% arrange(desc(weight)) %>% head(5)

for (donor in top_donors$iso3c) {
  # Re-run excluding this donor
  temp_pool <- setdiff(donor_pool, donor)
  result <- run_scm_analysis(config, wdi_data, temp_pool)
  
  cat(sprintf("Excluding %s: Effect = %.3f (Δ = %.3f)\n",
              donor, result$effect, result$effect - baseline_effect))
}
```

### Interpretation
```
Leave-One-Out Diagnostics:

Excluded      Weight  Effect    Δ vs Main
Baseline      --      -0.452    --
South Korea   32.5%   -0.438    +0.014   ✓ Small change
Thailand      21.3%   -0.461    -0.009   ✓ Small change
Singapore     18.8%   -0.447    +0.005   ✓ Small change
Chile         10.2%   -0.454    -0.002   ✓ Small change
Indonesia     8.5%    -0.449    +0.003   ✓ Small change

Conclusion:
  ✓ Maximum change: 0.014 (3% of effect)
  ✓ No single donor drives results
  ✓ Results robust to donor composition
```

### When to Worry
- ❌ Any Δ > 0.10: Single donor has large influence
- ⚠️ Any Δ > 0.05: Moderate influence, investigate
- ✅ All Δ < 0.05: Robust to individual donors

### Methodological Impact
- ❌ Without: Can't rule out single-donor driven results
- ✅ With: Demonstrates results not driven by outliers

---

## Best Practice 7: Post-Treatment Shock Detection

### Why It Matters
Donors experiencing **major shocks** post-treatment (wars, famines, policy changes) provide contaminated counterfactuals.

### When to Apply
✅ When analyzing developing countries (higher shock risk)  
✅ When post-period is long (>20 years, more time for shocks)  
⚠️ Optional for stable OECD countries, short periods

### Implementation
```r
# Compute pre-treatment SD for each donor
donor_pre_sd <- wdi_data %>%
  filter(iso3c %in% donor_pool, year < treatment_year) %>%
  group_by(iso3c) %>%
  summarize(pre_sd = sd(outcome, na.rm = TRUE))

# Check for large post-treatment changes
shocks <- wdi_data %>%
  filter(iso3c %in% donor_pool, year >= treatment_year) %>%
  left_join(donor_pre_sd, by = "iso3c") %>%
  group_by(iso3c) %>%
  mutate(z_score = (outcome - lag(outcome)) / pre_sd) %>%
  filter(abs(z_score) > 2.0)  # > 2 SD

if (nrow(shocks) > 0) {
  warning("%d shocks detected", nrow(shocks))
  print(shocks)
}
```

### Example Output
```
Post-Treatment Shock Detection:
WARNING: 3 shocks detected (>2.0 SD)

iso3c  year  outcome_change  z_score  context
RWA    1994  -1.2           -3.8     Rwandan genocide
IRQ    1991  -0.8           -2.4     Gulf War
AFG    2001  -0.9           -2.3     Afghanistan war

Recommendation:
  Exclude these donors and re-run analysis
  Command: --donor_exclude_iso3=TWN,HKG,MAC,RWA,IRQ,AFG
```

### What to Investigate
- **Wars**: Major conflicts disrupting fertility
- **Famines**: Food crises affecting survival
- **Policy changes**: Other fertility policies (Iran 1989, Vietnam 1988)
- **Data errors**: Sudden jumps/drops that seem implausible
- **Economic crises**: Asian Financial Crisis (1997), etc.

### Methodological Impact
- ❌ Without: May include contaminated donors (biased counterfactual)
- ✅ With: Cleaner counterfactual (only stable donors)

---

## Best Practice 8: Standardized Effect Sizes

### Why It Matters
Absolute effects (-0.45 births per woman) are:
- **Not comparable** across studies (different baseline TFR)
- **Not interpretable** without context (is 0.45 large or small?)

Standardized metrics enable **cross-study comparison** and **effect magnitude interpretation**.

### When to Apply
✅ **Always** for publication  
✅ When comparing to other studies  
✅ When effect magnitude is debated

### Metrics to Report

| Metric | Formula | Interpretation |
|--------|---------|----------------|
| **Absolute** | Avg(China - Synth) | Raw TFR difference |
| **% Change** | (Effect / Baseline TFR) × 100 | Relative to baseline |
| **Cohen's d** | Effect / SD(China pre) | Standardized units |
| **Effect/year** | Effect / Years post-treatment | Annual effect |
| **Relative MSPE** | MSPE ratio / Median(placebos) | Vs typical donor |

### Implementation
```r
baseline_tfr <- mean(china_pre$outcome)  # e.g., 1.5
baseline_sd <- sd(china_pre$outcome)     # e.g., 0.67

effect_sizes <- list(
  absolute = -0.452,
  pct_change = (-0.452 / 1.5) * 100,  # -30.1%
  cohens_d = -0.452 / 0.67,            # -0.67
  per_year = -0.452 / (2015 - 1980 + 1),  # -0.013/year
  rel_mspe = 4.98 / 1.76               # 2.83×
)
```

### Interpretation Guide

**Cohen's d**:
- |d| < 0.2: Small effect
- 0.2 ≤ |d| < 0.5: Medium effect
- 0.5 ≤ |d| < 0.8: Large effect
- |d| ≥ 0.8: Very large effect

**% Change**:
- <10%: Modest effect
- 10-30%: Substantial effect
- >30%: Very large effect

### Reporting Example
```
Effect Size Analysis:

Metric              Value          Interpretation
Absolute effect     -0.452         0.45 fewer births per woman
Percentage change   -30.1%         30% reduction from baseline
Cohen's d           -0.67          Large effect (social science std)
Effect per year     -0.013/year    Accumulates slowly
Relative MSPE       2.83×          China 2.8× more extreme than median placebo

Contextualization:
  - Policy reduced TFR by 30% of its baseline level (1.5 → 1.05)
  - Effect size is "large" by social science standards (d > 0.5)
  - Comparable to effects of: [cite similar studies]
  - Larger than natural fertility decline in controls (~15%)
```

### Methodological Impact
- ❌ Without: Hard to assess magnitude, can't compare studies
- ✅ With: Effect interpretable, comparable across contexts

---

## Best Practice 9: Enhanced Visualizations

### Why It Matters
Standard plots (TFR path, gap, placebo hist) are good but don't show:
- **How donors contribute** over time
- **Sensitivity** of results
- **Influence** of individual donors

### When to Apply
✅ For publication (especially top journals)  
✅ When presenting to non-technical audiences  
⚠️ Optional for internal analyses

### Additional Plots

**A. Donor Contribution Plot**
```r
# Stacked area showing each donor's contribution to synthetic TFR
contribution_df <- data.frame()
for (t in years) {
  for (d in donors_with_weight) {
    contrib <- donor_tfr[t, d] * donor_weight[d]
    contribution_df <- rbind(contribution_df,
      data.frame(year = t, donor = d, contribution = contrib))
  }
}

ggplot(contribution_df, aes(x = year, y = contribution, fill = donor)) +
  geom_area(position = "stack") +
  geom_line(data = china, aes(y = tfr), color = "red", size = 1.5) +
  labs(title = "Donor Contributions to Synthetic China",
       subtitle = "Red line = Actual China | Stacked areas = Synthetic contributors")
```

**Benefits**:
- ✅ Shows which donors drive synthetic at each time
- ✅ Visualizes donor importance beyond weights
- ✅ Reveals if contributions change over time

**B. Sensitivity Tornado Plot**
```r
# Show effect range across specifications
ggplot(sensitivity_results, aes(y = specification, x = effect)) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = effect_lower, xmax = effect_upper), height = 0.2) +
  geom_vline(xintercept = baseline_effect, linetype = "dashed", color = "red") +
  labs(title = "Sensitivity of Effect Estimate Across Specifications",
       x = "Effect Estimate (Births per Woman)",
       y = "Specification")
```

**Benefits**:
- ✅ Shows range of plausible effects
- ✅ Identifies which choices matter most
- ✅ Demonstrates robustness visually

**C. Leave-One-Out Plot**
```r
# Show effect when excluding each top donor
ggplot(loo_results, aes(x = reorder(excluded, -effect), y = effect)) +
  geom_point(size = 3) +
  geom_hline(yintercept = baseline, linetype = "dashed", color = "red") +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  coord_flip() +
  labs(title = "Leave-One-Out Diagnostic",
       x = "Excluded Donor",
       y = "Effect Estimate")
```

**Benefits**:
- ✅ Shows influence of each donor
- ✅ Identifies potentially problematic donors
- ✅ Demonstrates robustness to composition

### Methodological Impact
- ❌ Without: Harder to communicate findings, less transparent
- ✅ With: Clearer communication, increased transparency

---

## Best Practice 10: sessionInfo() Logging

### Why It Matters
**Reproducibility** requires documenting:
- R version
- Package versions (especially Synth, dplyr, ggplot2)
- Platform (OS, architecture)
- LAPACK/BLAS libraries (affect numerical optimization)

### When to Apply
✅ **Always** for publication  
✅ **Always** when sharing code/results  
✅ **Always** for replication packages

### Implementation
```r
# Save at end of script
session_file <- file.path(config$output_dir, "session_info.txt")
sink(session_file)
cat("R Session Information\n")
cat("Analysis Date:", as.character(Sys.time()), "\n\n")
sessionInfo()
sink()
```

### What to Include in Paper
```
Computational Environment:
  Analysis conducted in R 4.3.1 (2023-06-16) on macOS 13.4
  Key packages: Synth 1.1-6, WDI 2.7.8, dplyr 1.1.2, ggplot2 3.4.2
  Random seed: 20231108
  Full session info: see online appendix
```

### Methodological Impact
- ❌ Without: Results may not be **exactly reproducible**
- ✅ With: Full **computational reproducibility** ensured

---

## Complete Workflow: Production Analysis

### Step 1: Exploratory Run (V1)
```bash
# Quick check with fixed script
Rscript run_scm.R

# Examine results
cat scm_results/donor_filter_log.txt
cat scm_results/summary_stats.csv
```

**Check**:
- [ ] Donor count ≥ 10?
- [ ] Pre-RMSPE < 0.3?
- [ ] Effect direction makes sense?
- [ ] No "dataprep dropped donors" warning?

### Step 2: Validation Run (V2)
```bash
# Run with strict validation
Rscript run_scm_v2.R

# Should pass all checks
```

**Check**:
- [ ] No validation errors?
- [ ] ✓ marks for all checks?
- [ ] Donor pool size acceptable?

### Step 3: Sensitivity Analysis
```bash
# Coverage threshold
for cov in 0.7 0.75 0.8 0.85; do
  Rscript run_scm.R --min_pre_coverage=$cov \
    --output_dir="scm_results_cov${cov/./}"
done

# Pre-period length
Rscript run_scm.R --pre_period=1970,1979 --output_dir=scm_results_1970
Rscript run_scm.R --pre_period=1965,1979 --output_dir=scm_results_1965

# Regional restrictions
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --output_dir=scm_results_asia_latam
```

### Step 4: Leave-One-Out
```bash
# Get top 5 donors from main results
top_donors=$(head -6 scm_results/donor_weights.csv | tail -5 | cut -d',' -f2)

for donor in $top_donors; do
  Rscript run_scm.R \
    --donor_exclude_iso3="TWN,HKG,MAC,$donor" \
    --output_dir="scm_results_no_$donor"
done
```

### Step 5: Compile Results
```bash
# Extract key metrics
for dir in scm_results*; do
  effect=$(grep "Avg Post-treatment Gap" $dir/summary_stats.csv | cut -d',' -f2)
  donors=$(grep "N Donors" $dir/summary_stats.csv | cut -d',' -f2)
  pval=$(grep "Placebo p-value" $dir/summary_stats.csv | cut -d',' -f2)
  echo "$dir: Effect=$effect, Donors=$donors, P=$pval"
done
```

### Step 6: Final Documentation
1. ✅ Main results (`scm_results/`)
2. ✅ Sensitivity table (compile from runs)
3. ✅ Leave-one-out table
4. ✅ Session info (`session_info.txt`)
5. ✅ All plots (6-8 figures)
6. ✅ Data sources documented
7. ✅ Code archived (Dataverse/GitHub)

---

## Troubleshooting by Issue

### Issue: Donor pool too small (<10)
**Try**:
1. Lower coverage: `--min_pre_coverage=0.7`
2. Fewer predictors: `--min_predictors_ok=1`
3. Interpolation: `--interpolate_small_gaps=TRUE`
4. Shorter period: `--pre_period=1970,1979`

### Issue: Poor pre-treatment fit (RMSPE >0.5)
**Try**:
1. More donors (see above)
2. Different predictors
3. Special predictors only
4. Check for outlier donors

### Issue: Results not robust to specification
**Try**:
1. Check for influential donors (leave-one-out)
2. Check for shocked donors (post-treatment)
3. Consider different pre-period
4. Report range of effects, not point estimate

### Issue: P-value not significant (>0.20)
**Interpret**:
- May be **true result** (effect genuinely small/noisy)
- Still valuable if:
  - Pre-fit is good (RMSPE <0.3)
  - Effect size is substantial (>0.3)
  - Direction is correct
- Report as **descriptive evidence**, not causal proof

---

## Summary: When to Use Each Practice

| Practice | Always | Publication | High-Stakes | Optional |
|----------|--------|-------------|-------------|----------|
| Pre-treatment validation | ✅ | ✅ | ✅ | ✅ |
| Min donor enforcement | ✅ | ✅ | ✅ | ✅ |
| Cross-validation | | ✅ | ✅ | ⚠️ |
| Fixed placebo logic | ✅ | ✅ | ✅ | ✅ |
| Sensitivity analysis | | ✅ | ✅ | ⚠️ |
| Leave-one-out | | ✅ | ✅ | ⚠️ |
| Shock detection | ⚠️ | ✅ | ✅ | |
| Standardized effects | | ✅ | ✅ | ⚠️ |
| Enhanced plots | | ✅ | ✅ | |
| sessionInfo() | | ✅ | ✅ | ⚠️ |

**Legend**:
- ✅ **Always**: Should be used in all analyses
- ⚠️ **Conditional**: Depends on context (see "When to Apply" sections)
- Blank: Nice to have but not critical

---

**Marker "2"** - Best Practices Implementation Guide Complete

This guide provides practical implementation advice for all 10+ SCM best practices. Use in conjunction with `run_scm_v2.R` for production-grade analyses.
