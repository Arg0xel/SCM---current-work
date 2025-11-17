#!/bin/bash
################################################################################
# Example Commands for Synthetic Control Analysis
################################################################################
# This file contains example commands for running the SCM analysis
# with different configurations. Copy and modify as needed.
################################################################################

# ==============================================================================
# BASIC EXAMPLES
# ==============================================================================

# 1. Default analysis (all donors, 1960-2015, treatment in 1980)
Rscript run_scm.R

# 2. View help (shows configuration options)
# Note: Add --help flag support to script if desired
# For now, see README.md for parameter documentation

# ==============================================================================
# TIME PERIOD ADJUSTMENTS
# ==============================================================================

# 3. Use 1981 as treatment year instead of 1980
Rscript run_scm.R --treatment_year=1981

# 4. Shorter pre-period (useful if early data is sparse)
Rscript run_scm.R --pre_period=1965,1979

# 5. End analysis in 2014 (exclude 2015 policy reversal)
Rscript run_scm.R --post_period_end=2014

# 6. Or use convenience flag
Rscript run_scm.R --end_year_exclude_2015_policy_change=TRUE

# ==============================================================================
# DONOR POOL RESTRICTIONS
# ==============================================================================

# 7. Use only East Asia & Pacific and Latin America & Caribbean
Rscript run_scm.R --donor_include_regions="East Asia & Pacific,Latin America & Caribbean"

# 8. Use only upper-middle and high-income countries
Rscript run_scm.R --donor_include_income_groups="Upper middle income,High income"

# 9. Exclude Sub-Saharan Africa
Rscript run_scm.R --donor_exclude_regions="Sub-Saharan Africa"

# 10. Manually specify donor pool (example: Asian and Latin American countries)
Rscript run_scm.R --donor_include_iso3="KOR,THA,MYS,IDN,PHL,MEX,BRA,TUR,CHL,COL"

# 11. Exclude specific countries (e.g., city-states)
Rscript run_scm.R --donor_exclude_iso3="TWN,HKG,MAC,SGP"

# 12. Allow microstates in donor pool
Rscript run_scm.R --remove_microstates_by_name=FALSE

# ==============================================================================
# DATA QUALITY SETTINGS
# ==============================================================================

# 13. More lenient data requirements (lower coverage threshold)
Rscript run_scm.R --min_pre_coverage=0.7

# 14. Disable interpolation
Rscript run_scm.R --interpolate_small_gaps=FALSE

# 15. Allow longer gaps to interpolate
Rscript run_scm.R --max_gap_to_interpolate=5

# ==============================================================================
# PLACEBO TEST CONFIGURATION
# ==============================================================================

# 16. Limit number of placebos (for speed)
Rscript run_scm.R --placebo_max_n=30

# 17. Use stricter pre-fit filter (relative to China's fit)
Rscript run_scm.R --placebo_prefit_filter="relative" --placebo_prefit_filter_value=2.0

# 18. Use quantile-based filter (exclude worst-fitting placebos)
Rscript run_scm.R --placebo_prefit_filter="quantile" --placebo_prefit_filter_value=0.85

# 19. No pre-fit filter (include all placebos in p-value)
Rscript run_scm.R --placebo_prefit_filter="none"

# 20. Change in-time placebo year
Rscript run_scm.R --in_time_placebo_year=1975

# ==============================================================================
# OUTPUT CONFIGURATION
# ==============================================================================

# 21. Save results to different directory
Rscript run_scm.R --output_dir="results_baseline"

# ==============================================================================
# COMBINED EXAMPLES (COMMON USE CASES)
# ==============================================================================

# 22. Conservative analysis: Regional restriction + stricter filter
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --post_period_end=2014 \
  --placebo_prefit_filter="relative" \
  --placebo_prefit_filter_value=2.0 \
  --output_dir="results_conservative"

# 23. Income-matched donors + shorter pre-period
Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income" \
  --pre_period=1965,1979 \
  --output_dir="results_income_matched"

# 24. Manual donor pool (development economists' common choice)
Rscript run_scm.R \
  --donor_include_iso3="KOR,THA,MYS,IDN,PHL,VNM,MEX,BRA,TUR,CHL,COL,IRN,EGY" \
  --output_dir="results_manual_donors"

# 25. Fast exploratory analysis (fewer placebos)
Rscript run_scm.R \
  --placebo_max_n=20 \
  --output_dir="results_quick"

# 26. Sensitivity to treatment year
Rscript run_scm.R \
  --treatment_year=1979 \
  --output_dir="results_treatment_1979"

Rscript run_scm.R \
  --treatment_year=1981 \
  --output_dir="results_treatment_1981"

# 27. Robustness: Different predictor set (requires editing script)
# Note: To change predictors, edit config.yaml:
#   predictors_wdi_codes:
#     - "NY.GDP.PCAP.KD"
#     - "SP.DYN.LE00.IN"
#     - "SP.URB.TOTL.IN.ZS"
#     - "SE.PRM.ENRR"  # Add primary school enrollment

# ==============================================================================
# BATCH PROCESSING EXAMPLE
# ==============================================================================

# 28. Run multiple configurations and compare
echo "Running baseline analysis..."
Rscript run_scm.R --output_dir="results_baseline"

echo "Running regional restriction..."
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean" \
  --output_dir="results_regional"

echo "Running income-matched..."
Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income,High income" \
  --output_dir="results_income"

echo "Running manual donor pool..."
Rscript run_scm.R \
  --donor_include_iso3="KOR,THA,MYS,IDN,PHL,MEX,BRA,TUR" \
  --output_dir="results_manual"

echo "All analyses complete! Compare results in:"
echo "  - results_baseline/"
echo "  - results_regional/"
echo "  - results_income/"
echo "  - results_manual/"

# ==============================================================================
# NOTES
# ==============================================================================
# 
# 1. All examples assume you're in the directory containing run_scm.R
#
# 2. To see full output, run without redirecting:
#    Rscript run_scm.R [options]
#
# 3. To save console output to log file:
#    Rscript run_scm.R [options] 2>&1 | tee analysis.log
#
# 4. To suppress console output:
#    Rscript run_scm.R [options] > /dev/null 2>&1
#
# 5. Check exit code to verify success:
#    Rscript run_scm.R && echo "Success!" || echo "Failed!"
#
# 6. For parallel execution (requires GNU parallel):
#    parallel ::: \
#      "Rscript run_scm.R --output_dir=results_1" \
#      "Rscript run_scm.R --treatment_year=1981 --output_dir=results_2"
#
# ==============================================================================
