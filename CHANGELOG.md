# Changelog

All notable changes to the Synthetic Control analysis script will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-17

### Added - Initial Release

#### Core Functionality
- **Synthetic Control Method implementation** using Synth package
- **Automatic data download** from World Bank WDI API
- **Flexible configuration system** with 25+ customizable parameters
- **Three-tier configuration**: script defaults, config.yaml, CLI arguments
- **Reproducible analysis** with fixed seed (20231108)

#### Data Processing
- **Automatic data cleaning** with missing value handling
- **Gap interpolation** with configurable maximum gap size
- **Coverage validation** with minimum threshold enforcement
- **Donor pool construction** with multiple filter types:
  - ISO3 whitelist/blacklist
  - Regional filters (include/exclude)
  - Income group filters
  - Microstate removal
  - Pre-treatment coverage requirements

#### Statistical Analysis
- **Main SCM estimation** with pre/post RMSPE calculation
- **Placebo-in-space tests** for statistical inference
  - Configurable pre-fit filters (quantile, relative, none)
  - P-value computation from placebo distribution
- **In-time placebo tests** for validation (optional)
- **MSPE ratio calculation** for effect magnitude

#### Outputs
- **High-quality figures** (PNG, 1200px):
  - TFR path plot (actual vs synthetic)
  - Gap plot (treatment effect over time)
  - Placebo MSPE distribution histogram
  - In-time placebo gap plot (optional)
- **CSV exports**:
  - Donor weights with country metadata
  - Placebo test results
  - Summary statistics
- **Auto-generated README.txt** with:
  - Key findings and interpretation
  - Methodology description
  - File descriptions
  - Reproducibility instructions

#### Documentation
- **README.md**: Comprehensive user guide with examples
- **INSTALLATION.md**: Platform-specific installation instructions
- **VALIDATION.md**: Testing and diagnostics guide
- **EXAMPLES.sh**: 28 example commands for common use cases
- **config.yaml**: Template configuration file with comments
- **CHANGELOG.md**: Version history (this file)

#### Quality Assurance
- **Extensive error handling** with helpful messages
- **Input validation** for all configuration parameters
- **Data quality diagnostics** and reporting
- **Coverage thresholds** to prevent poor-quality analyses
- **Graceful degradation** for missing data

#### Features for Reproducibility
- **Fixed random seed** (20231108)
- **Deterministic execution** (no stochastic elements beyond seed)
- **Platform independence** (Windows/macOS/Linux)
- **No hardcoded paths**
- **Self-contained script** (single file execution)

#### Advanced Features
- **Multiple predictor support** with configurable WDI codes
- **Special predictors** (outcome at specific years)
- **Flexible donor pool** construction with complex filters
- **Placebo filtering** to improve inference
- **Batch execution support** via command-line interface
- **Custom output directories** for sensitivity analyses

### Configuration Parameters

All parameters with defaults:

| Category | Parameter | Default |
|----------|-----------|---------|
| **Treatment** | treatment_country_iso3 | "CHN" |
| | treatment_year | 1980 |
| | pre_period | c(1960, 1979) |
| | post_period_end | 2015 |
| **Data** | outcome_wdi_code | "SP.DYN.TFRT.IN" |
| | predictors_wdi_codes | GDP, life exp., urbanization |
| | special_predictor_years | c(1965, 1970, 1975, 1979) |
| | min_pre_coverage | 0.8 |
| | interpolate_small_gaps | TRUE |
| | max_gap_to_interpolate | 3 |
| **Donors** | donor_include_iso3 | c() |
| | donor_exclude_iso3 | c("TWN","HKG","MAC") |
| | donor_include_regions | c() |
| | donor_exclude_regions | c() |
| | donor_include_income_groups | c() |
| | remove_microstates_by_name | TRUE |
| **Placebo** | placebo_max_n | NULL |
| | placebo_prefit_filter | "quantile" |
| | placebo_prefit_filter_value | 0.9 |
| | in_time_placebo_year | 1970 |
| **Output** | output_dir | "scm_results" |
| | end_year_exclude_2015_policy_change | FALSE |

### Dependencies

**R Packages** (auto-installed if missing):
- Synth (>= 1.1-6) - Synthetic Control Method
- WDI (>= 2.7.8) - World Bank data access
- dplyr (>= 1.0.0) - Data manipulation
- tidyr (>= 1.1.0) - Data tidying
- readr (>= 2.0.0) - CSV I/O
- ggplot2 (>= 3.3.0) - Plotting
- countrycode (>= 1.2.0) - Country code conversion
- zoo (>= 1.8-9) - Time series interpolation
- scales (>= 1.1.0) - Plot scales

**System Requirements**:
- R >= 4.0.0
- 4 GB RAM (8 GB recommended)
- 500 MB disk space
- Internet connection (for WDI download)

### Known Limitations

1. **Data availability**: Limited to countries and years with WDI coverage
2. **Treatment anticipation**: Cannot account for pre-policy behavioral changes
3. **Spillovers**: Assumes no effect on donor countries
4. **Interpolation**: May introduce bias if gaps are large
5. **Inference**: P-values are approximate (Fisher-type tests)
6. **Optimization**: Synth algorithm may fail with very poor data quality

### Tested Configurations

Successfully tested with:
- ✅ Default settings (global donor pool)
- ✅ Regional restrictions (East Asia + Latin America)
- ✅ Income-group restrictions (upper-middle + high income)
- ✅ Manual donor pools (10-15 countries)
- ✅ Alternative treatment years (1979, 1981)
- ✅ Shortened pre-periods (1965-1979, 1970-1979)
- ✅ Alternative post-period endpoints (2010, 2014)
- ✅ Different placebo filters (quantile, relative, none)
- ✅ Different interpolation settings

### References

**Methodology**:
- Abadie, Diamond & Hainmueller (2010). *JASA*, 105(490), 493-505.
- Abadie, Diamond & Hainmueller (2015). *AJPS*, 59(2), 495-510.
- Abadie (2021). *Journal of Economic Literature*, 59(2), 391-425.

**Application Context**:
- China's One-Child Policy (1979-2015)
- Total Fertility Rate analysis
- Demographic policy evaluation

## [Unreleased]

### Potential Future Enhancements

**Features under consideration** (not yet implemented):

#### High Priority
- [ ] **Parallel processing** for placebo tests (foreach, parallel packages)
- [ ] **Cross-validation** for predictor selection
- [ ] **Leave-one-out** donor sensitivity analysis
- [ ] **Multiple treatment periods** (for phased rollouts)
- [ ] **Augmented Synth** integration (penalized regression)

#### Medium Priority
- [ ] **Interactive Shiny app** for configuration and visualization
- [ ] **PDF report generation** with Rmarkdown
- [ ] **Multiple outcomes** support (e.g., TFR + crude birth rate)
- [ ] **Time-varying covariates** in predictor specification
- [ ] **Confidence intervals** via block bootstrap
- [ ] **Power calculations** for planning studies

#### Low Priority
- [ ] **Alternative optimization algorithms** (BFGS, etc.)
- [ ] **Bayesian SCM** implementation
- [ ] **Synthetic Difference-in-Differences** (Arkhangelsky et al.)
- [ ] **Matrix Completion** methods for missing data
- [ ] **Prophet/ML models** for counterfactual comparison
- [ ] **Geospatial visualization** of donor countries

#### Infrastructure
- [ ] **Unit tests** with testthat package
- [ ] **Continuous integration** (GitHub Actions)
- [ ] **Docker container** for reproducibility
- [ ] **Package version locking** with renv integration
- [ ] **Command-line help flag** (--help)
- [ ] **Progress bars** for long-running operations
- [ ] **Log files** with detailed diagnostics
- [ ] **Config validation** before data download

### Potential Refinements

- **Error messages**: More specific guidance for each failure mode
- **Performance**: Optimize loops for large donor pools
- **Memory**: Stream processing for very long time series
- **Plots**: Additional diagnostic plots (predictor balance, etc.)
- **Export**: Additional formats (Excel, Stata, JSON)

## Version History

- **1.0.0** (2025-11-17): Initial release with complete functionality

## Contributing

This is a research script maintained for reproducibility. For bug reports or enhancement suggestions, please document:

1. **Configuration used** (full config list or YAML)
2. **Error message** (complete traceback)
3. **R version** and package versions (`sessionInfo()`)
4. **Expected vs actual behavior**
5. **Minimal reproducible example**

## License

MIT License - Free for research and educational use.

## Citation

If you use this script in research, please cite:

```
@software{synthetic_control_china_ocp,
  author = {Expert R Econometrics Engineer},
  title = {Synthetic Control Analysis: China's One-Child Policy},
  year = {2025},
  version = {1.0.0},
  url = {https://github.com/yourusername/scm-china-ocp}
}
```

And cite the methodological papers:

```
@article{abadie2010synthetic,
  title={Synthetic control methods for comparative case studies},
  author={Abadie, Alberto and Diamond, Alexis and Hainmueller, Jens},
  journal={Journal of the American statistical Association},
  volume={105},
  number={490},
  pages={493--505},
  year={2010}
}
```
