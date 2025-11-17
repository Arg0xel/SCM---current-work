# Synthetic Control Analysis: China's One-Child Policy

A fully reproducible R implementation of Synthetic Control Method (SCM) to estimate the causal effect of China's One-Child Policy (introduced 1979–1980) on Total Fertility Rate (TFR).

## 🎯 Overview

This analysis uses the Synthetic Control Method to answer: **What would China's fertility rate have been without the One-Child Policy?**

The method constructs a "synthetic China" from a weighted combination of donor countries that closely matches China's pre-policy characteristics. The difference between actual China and synthetic China after 1980 is interpreted as the policy's causal effect.

## 📋 Features

- **Fully automated**: Downloads data, fits model, generates plots and tables
- **Highly configurable**: 25+ parameters exposed via script, YAML, or CLI
- **Reproducible**: Fixed seed (20231108), version-controlled dependencies
- **Statistically rigorous**: Includes placebo tests and inference
- **Publication-ready**: High-quality plots and CSV outputs
- **Beginner-friendly**: Extensive comments and error messages

## 🚀 Quick Start

### Prerequisites

- R (≥ 4.0.0)
- Internet connection (for downloading World Bank data)

### Installation

1. Install required R packages (script will auto-install):
   ```r
   install.packages(c("Synth", "WDI", "tidyverse", "ggplot2", 
                      "countrycode", "zoo", "scales"))
   ```

2. Download the script:
   ```bash
   # All you need is run_scm.R
   ```

### Run with Defaults

```bash
Rscript run_scm.R
```

This runs the analysis with default settings:
- Treatment: China (CHN), 1980
- Pre-period: 1960–1979
- Post-period: 1980–2015
- All available donors (excluding aggregates and microstates)

### Run with Custom Parameters

**Option 1: Edit `config.yaml`**
```yaml
treatment_year: 1981
post_period_end: 2014
donor_include_regions:
  - "East Asia & Pacific"
  - "Latin America & Caribbean"
```

**Option 2: Command-line arguments**
```bash
Rscript run_scm.R \
  --treatment_year=1981 \
  --post_period_end=2014 \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean"
```

**Option 3: Edit the config block at the top of `run_scm.R`**

## 📊 Outputs

The script creates a `scm_results/` directory with:

### Figures (PNG, 1200px wide)

1. **`tfr_path.png`**: China vs Synthetic China TFR trajectories
   - Shows how well synthetic control matches pre-treatment
   - Reveals post-treatment divergence (treatment effect)

2. **`tfr_gap.png`**: Treatment effect over time
   - Gap = China − Synthetic China
   - Negative gap = China's TFR lower than counterfactual

3. **`placebo_mspe_hist.png`**: Placebo test distribution
   - Histogram of MSPE ratios from placebo tests
   - Red line shows China's ratio
   - Tests statistical significance

4. **`tfr_gap_in_time_placebo.png`** (optional): In-time placebo
   - Robustness check: fake treatment before real policy
   - Should show no systematic effect

### Tables (CSV)

1. **`donor_weights.csv`**: Countries used to construct synthetic China
   - Shows which countries contribute and how much
   - Includes country name, ISO3 code, weight, region, income

2. **`placebo_results.csv`**: All placebo test results
   - One row per placebo country
   - Pre/post RMSPE, MSPE ratio, country metadata

3. **`summary_stats.csv`**: Key metrics
   - Pre/post RMSPE, MSPE ratio
   - Placebo p-value
   - Average treatment effect
   - Sample sizes

### Documentation

4. **`README.txt`**: Auto-generated analysis summary
   - Key findings and interpretation
   - Lists all outputs with descriptions
   - Reproducibility instructions

## ⚙️ Configuration Reference

### Core Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `treatment_country_iso3` | `"CHN"` | ISO3 code of treated unit |
| `treatment_year` | `1980` | Year policy was introduced |
| `pre_period` | `c(1960, 1979)` | Pre-treatment period |
| `post_period_end` | `2015` | End of analysis period |

### Data Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `outcome_wdi_code` | `"SP.DYN.TFRT.IN"` | World Bank indicator for outcome |
| `predictors_wdi_codes` | GDP, life exp., urban | Predictors for matching |
| `special_predictor_years` | `c(1965,1970,1975,1979)` | Years to match outcome exactly |
| `min_pre_coverage` | `0.8` | Min % non-missing outcome data |
| `interpolate_small_gaps` | `TRUE` | Fill small data gaps |
| `max_gap_to_interpolate` | `3` | Max years to interpolate |

### Donor Pool Filters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `donor_include_iso3` | `c()` | Whitelist (if not empty, only these used) |
| `donor_exclude_iso3` | `c("TWN","HKG","MAC")` | Blacklist |
| `donor_include_regions` | `c()` | Include only these regions |
| `donor_exclude_regions` | `c()` | Exclude these regions |
| `donor_include_income_groups` | `c()` | Include only these income levels |
| `remove_microstates_by_name` | `TRUE` | Exclude small countries |

### Placebo Test Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `placebo_max_n` | `NULL` | Max placebos to run (NULL = all) |
| `placebo_prefit_filter` | `"quantile"` | Filter method: "quantile", "relative", "none" |
| `placebo_prefit_filter_value` | `0.9` | Quantile threshold or relative multiplier |
| `in_time_placebo_year` | `1970` | Year for in-time placebo test |

### Output

| Parameter | Default | Description |
|-----------|---------|-------------|
| `output_dir` | `"scm_results"` | Directory for results |
| `end_year_exclude_2015_policy_change` | `FALSE` | If TRUE, sets post_period_end to 2014 |

## 🔬 Methodology

### Synthetic Control Method

The SCM constructs a weighted average of donor countries that best approximates the treated unit (China) before treatment:

1. **Match on predictors**: GDP per capita, life expectancy, urbanization
2. **Match on outcome history**: TFR at 1965, 1970, 1975, 1979
3. **Optimize weights**: Minimize pre-treatment RMSPE
4. **Estimate effect**: Difference between actual and synthetic post-treatment

### Statistical Inference

**Placebo-in-Space Test**: Re-run SCM treating each donor as if it were treated. Compute MSPE ratios for all placebos. The p-value is the proportion of placebos with ratios ≥ China's ratio.

**Pre-fit Filter**: Exclude placebos with very poor pre-treatment fit (configurable):
- `"quantile"`: Drop worst X% by pre-RMSPE (default: 10%)
- `"relative"`: Drop placebos with pre-RMSPE > k × China's (default: k=2)
- `"none"`: Use all placebos

**In-Time Placebo**: Robustness check placing fake treatment in pre-period. Should show no effect if model is valid.

### Metrics

- **Pre-RMSPE**: Root mean squared prediction error before treatment (measures fit quality)
- **Post-RMSPE**: RMSPE after treatment
- **MSPE Ratio**: Post-MSPE / Pre-MSPE (large ratio suggests significant effect)
- **Placebo p-value**: Statistical significance via placebo distribution

## 📝 Example Use Cases

### Example 1: Default Analysis (All Donors)

```bash
Rscript run_scm.R
```

Uses all available countries as potential donors.

### Example 2: Regional Restriction

```bash
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean"
```

Limits donors to countries in similar regions.

### Example 3: Income-Based Donor Pool

```bash
Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income,High income"
```

Uses only countries with comparable income levels.

### Example 4: Manual Donor Pool

Edit `config.yaml`:
```yaml
donor_include_iso3:
  - KOR  # South Korea
  - THA  # Thailand
  - MYS  # Malaysia
  - IDN  # Indonesia
  - PHL  # Philippines
  - MEX  # Mexico
  - BRA  # Brazil
  - TUR  # Turkey
  - CHL  # Chile
  - COL  # Colombia
```

### Example 5: Shorter Time Period

```bash
Rscript run_scm.R \
  --pre_period=1965,1979 \
  --post_period_end=2014
```

Useful if early data is sparse or to exclude 2015 policy change.

### Example 6: Sensitivity Analysis

```bash
# More stringent placebo filter
Rscript run_scm.R \
  --placebo_prefit_filter="relative" \
  --placebo_prefit_filter_value=2.0
```

Only includes placebos with pre-RMSPE ≤ 2× China's.

## 🐛 Troubleshooting

### Error: "China has insufficient outcome coverage"

**Problem**: Too much missing TFR data for China in pre-period.

**Solutions**:
1. Enable interpolation: `--interpolate_small_gaps=TRUE`
2. Increase max gap: `--max_gap_to_interpolate=5`
3. Shorten pre-period: `--pre_period=1965,1979`
4. Lower threshold: `--min_pre_coverage=0.7`

### Error: "Very small donor pool"

**Problem**: Filters are too restrictive.

**Solutions**:
1. Relax regional filters
2. Remove income restrictions
3. Reduce `min_pre_coverage`
4. Allow more microstates: `--remove_microstates_by_name=FALSE`

### Warning: "NA values found in predictors"

**Problem**: Missing data for predictor variables.

**Solution**: The script will warn but continue. Consider:
1. Enabling interpolation
2. Using different predictors
3. Checking data availability for your time period

### Synth optimization fails

**Problem**: Algorithm cannot find solution.

**Possible causes**:
- Poor data quality
- Too few donors
- Incompatible constraints

**Solutions**:
1. Check data coverage for all units
2. Expand donor pool
3. Simplify predictor set

## 📚 References

### Methodology

- Abadie, A., Diamond, A., & Hainmueller, J. (2010). [Synthetic Control Methods for Comparative Case Studies](https://www.tandfonline.com/doi/abs/10.1198/jasa.2009.ap08746). *Journal of the American Statistical Association*, 105(490), 493-505.

- Abadie, A., Diamond, A., & Hainmueller, J. (2015). [Comparative Politics and the Synthetic Control Method](https://onlinelibrary.wiley.com/doi/abs/10.1111/ajps.12116). *American Journal of Political Science*, 59(2), 495-510.

- Abadie, A. (2021). [Using Synthetic Controls: Feasibility, Data Requirements, and Methodological Aspects](https://www.aeaweb.org/articles?id=10.1257/jel.20191450). *Journal of Economic Literature*, 59(2), 391-425.

### R Package

- Synth: [CRAN](https://cran.r-project.org/package=Synth) | [Documentation](https://www.jstatsoft.org/article/view/v042i13)

### Data

- World Bank World Development Indicators: [https://datatopics.worldbank.org/world-development-indicators/](https://datatopics.worldbank.org/world-development-indicators/)

## 🤝 Contributing

This is a self-contained research script. For modifications:

1. All configuration parameters are in the `config` list at the top
2. Code is organized in numbered sections
3. Each section has clear comments
4. Use reproducibility seed: `set.seed(20231108)`

## 📄 License

This script is provided as-is for research and educational purposes.

## 🙋 Support

If the script fails with unclear error messages, check:
1. R version (≥ 4.0.0 recommended)
2. Package versions (install latest from CRAN)
3. Internet connection (required for WDI download)
4. Configuration parameter types (numeric vs character vs logical)

For research questions about SCM methodology, see the references above.

---

**Version**: 1.0  
**Date**: 2025-11-17  
**Author**: Expert R Econometrics Engineer  
**Reproducibility Seed**: 20231108
