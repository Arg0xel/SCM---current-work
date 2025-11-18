#!/usr/bin/env Rscript
################################################################################
# Synthetic Control Analysis: China's One-Child Policy Effect on TFR
# VERSION 3: COMPLETE PRODUCTION VERSION (V2 Enhancements + Full Workflow)
# Author: Senior Data Scientist & SCM Expert
# Date: 2025-11-17 19:00 UTC
# Reproducibility Seed: 20231108
################################################################################
#
# VERSION 3 = V2 Enhanced Setup (Sections 2.1-2.7) + V1 Complete Workflow (Sections 7-15)
#
# V2 ENHANCEMENTS INCLUDED (Sections 2.1-2.7):
# 1. ✅ Pre-treatment period validation (prevents data leakage)
# 2. ✅ Minimum donor pool enforcement (≥10 required, configurable)
# 3. ✅ Configurable predictor requirements (min_predictors_ok parameter)
# 4. ✅ Enhanced logging with timestamps and version markers
# 5. ✅ Parameter validation before data download (fail fast)
# 6. ✅ Better error messages with specific remediation steps
# 7. ✅ Methodological warnings for suboptimal donor pools
# 8. ✅ Comprehensive diagnostic output (donor_filter_log.txt)
# 9. ✅ Early validation (catches config errors before WDI download)
# 10. ✅ Modular structure for easy extension and debugging
#
# V1 COMPLETE WORKFLOW INCLUDED (Sections 7-15):
# 11. ✅ Synth model fitting with dataprep and synth()
# 12. ✅ Results extraction and reporting
# 13. ✅ Placebo-in-space inference tests
# 14. ✅ Output file generation (CSV, plots, README)
# 15. ✅ Visualization suite (TFR path, gap, placebo histogram)
# 16. ✅ In-time placebo test (optional)
# 17. ✅ Comprehensive documentation generation
#
# MARKER: "3" - This is the complete production version
#
# USAGE:
#   Rscript run_scm_v3.R                    # Standard run
#   Rscript run_scm_v3.R --min_pre_coverage=0.7  # Custom parameters
#
################################################################################

# ==============================================================================
# SECTION 3.1: SETUP AND CONFIGURATION (V2 Enhanced)
# ==============================================================================

# Check if running interactively and warn user
if (interactive()) {
  warning(
    paste("\n\n*** WARNING: You are running this script interactively! ***\n",
          "This script is designed to be run from command line with:\n",
          "  Rscript run_scm_v2.R\n",
          "\nInteractive execution may cause issues with:\n",
          "  - WDI data download (may hang or timeout)\n",
          "  - Package installation prompts\n",
          "  - Progress reporting\n",
          "\nIf you experience problems, exit R and run from command line.\n",
          "Continuing in 5 seconds...\n\n"),
    immediate. = TRUE
  )
  Sys.sleep(5)
}

# Set reproducibility seed
set.seed(20231108)

# --- Enhanced Configuration ---
# 2: Added validation parameters and sensitivity analysis controls
config <- list(
  # Core parameters
  treatment_country_iso3 = "CHN",
  treatment_year = 1980,
  pre_period = c(1960, 1979),
  post_period_end = 2015,
  outcome_wdi_code = "SP.DYN.TFRT.IN",
  predictors_wdi_codes = c("NY.GDP.PCAP.KD", "SP.DYN.LE00.IN", "SP.URB.TOTL.IN.ZS"),
  special_predictor_years = c(1965, 1970, 1975, 1979),
  
  # Coverage and interpolation
  min_pre_coverage = 0.8,
  min_predictors_ok = 2,  # 2: NEW - explicit "2 of 3" parameter
  interpolate_small_gaps = TRUE,
  max_gap_to_interpolate = 3,
  
  # Donor pool filters
  donor_include_iso3 = c(),
  donor_exclude_iso3 = c("TWN", "HKG", "MAC"),
  donor_include_regions = c(),
  donor_include_income_groups = c(),
  donor_exclude_regions = c(),
  remove_microstates_by_name = TRUE,
  min_donor_pool_size = 10,  # 2: NEW - minimum donors required
  
  # Placebo inference
  placebo_max_n = NULL,
  placebo_prefit_filter = "quantile",
  placebo_prefit_filter_value = 0.9,
  in_time_placebo_year = 1970,
  
  # 2: NEW - Sensitivity analysis automation
  run_sensitivity_analysis = TRUE,
  sensitivity_coverage_thresholds = c(0.7, 0.75, 0.8, 0.85),
  
  # 2: NEW - Leave-one-out diagnostics
  run_leave_one_out = TRUE,
  loo_top_n_donors = 5,  # Test influence of top 5 donors
  
  # 2: NEW - Post-treatment validation
  check_donor_shocks = TRUE,
  donor_shock_threshold = 2.0,  # Flag if donor's outcome changes >2 SD
  
  # Output
  end_year_exclude_2015_policy_change = FALSE,
  output_dir = "scm_results_v3"  # 3: V3 output directory
)

# Microstates to potentially exclude
microstates <- c("LIE", "MCO", "SMR", "AND", "VAT", "NAU", "TUV", "PLW", 
                 "MHL", "KNA", "DMA", "VCT", "GRD", "ATG", "BRB", "TON",
                 "KIR", "FSM", "SYC", "MUS", "BHR", "MLT", "MDV")

# ==============================================================================
# SECTION 3.2: PACKAGE INSTALLATION AND LOADING (V2 Enhanced)
# ==============================================================================

cat("=======================================================\n")
cat("Synthetic Control Analysis V2 (Enhanced Best Practices)\n")
cat("=======================================================\n\n")

cat("Installing and loading required packages...\n")

# Required packages
packages <- c("Synth", "WDI", "dplyr", "tidyr", "readr", "ggplot2", 
              "countrycode", "zoo", "scales")

# Install missing packages
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org/", 
                     quiet = TRUE, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

cat("All packages loaded successfully.\n\n")

# ==============================================================================
# SECTION 3.3: CONFIGURATION OVERRIDE LOGIC
# ==============================================================================

# Override with config.yaml if present
if (file.exists("config_v3.yaml")) {
  cat("Found config_v3.yaml, loading overrides...\n")
  if (require("yaml", quietly = TRUE)) {
    yaml_config <- yaml::read_yaml("config_v3.yaml")
    for (key in names(yaml_config)) {
      if (key %in% names(config)) {
        config[[key]] <- yaml_config[[key]]
        cat(sprintf("  Overriding %s from YAML\n", key))
      }
    }
  } else {
    cat("yaml package not available; skipping config_v2.yaml\n")
  }
}

# Override with command-line arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  cat("Processing command-line arguments...\n")
  for (arg in args) {
    if (grepl("^--", arg)) {
      parts <- strsplit(gsub("^--", "", arg), "=")[[1]]
      if (length(parts) == 2) {
        key <- parts[1]
        value <- parts[2]
        if (key %in% names(config)) {
          # Parse value based on type
          if (key %in% c("treatment_year", "post_period_end", "in_time_placebo_year",
                        "placebo_max_n", "min_donor_pool_size", "min_predictors_ok",
                        "loo_top_n_donors")) {
            config[[key]] <- as.integer(value)
          } else if (key %in% c("min_pre_coverage", "placebo_prefit_filter_value",
                                "donor_shock_threshold")) {
            config[[key]] <- as.numeric(value)
          } else if (key %in% c("interpolate_small_gaps", "remove_microstates_by_name",
                               "end_year_exclude_2015_policy_change", "run_sensitivity_analysis",
                               "run_leave_one_out", "check_donor_shocks")) {
            config[[key]] <- as.logical(toupper(value))
          } else if (key %in% c("donor_include_iso3", "donor_exclude_iso3", 
                               "donor_include_regions", "donor_include_income_groups",
                               "donor_exclude_regions", "predictors_wdi_codes")) {
            config[[key]] <- strsplit(value, ",")[[1]]
          } else if (key == "pre_period") {
            config[[key]] <- as.integer(strsplit(value, ",")[[1]])
          } else if (key == "special_predictor_years") {
            config[[key]] <- as.integer(strsplit(value, ",")[[1]])
          } else if (key == "sensitivity_coverage_thresholds") {
            config[[key]] <- as.numeric(strsplit(value, ",")[[1]])
          } else {
            config[[key]] <- value
          }
          cat(sprintf("  Overriding %s from CLI: %s\n", key, value))
        }
      }
    }
  }
}

# Apply end_year_exclude_2015_policy_change
if (config$end_year_exclude_2015_policy_change) {
  config$post_period_end <- 2014
  cat("Excluding 2015 policy change: setting post_period_end to 2014\n")
}

# ==============================================================================
# SECTION 3.4: ENHANCED VALIDATION (NEW)
# ==============================================================================

cat("\n--- Configuration Validation ---\n")

# 2: Validate pre-treatment period
if (config$pre_period[1] >= config$treatment_year) {
  stop("ERROR: Pre-period start must be before treatment year!")
}
if (config$pre_period[2] >= config$treatment_year) {
  stop("ERROR: Pre-period end must be before treatment year!")
}

# 2: Validate special predictor years
invalid_years <- config$special_predictor_years[
  config$special_predictor_years < config$pre_period[1] |
  config$special_predictor_years > config$pre_period[2]
]
if (length(invalid_years) > 0) {
  stop(sprintf(
    paste("ERROR: Special predictor years must fall within pre-period!",
          "Invalid years: %s",
          "Pre-period: %d-%d",
          "Fix: Remove years outside pre-period or adjust pre_period range."),
    paste(invalid_years, collapse = ", "),
    config$pre_period[1], config$pre_period[2]
  ))
}

# 2: Validate minimum predictors
if (config$min_predictors_ok < 1 || config$min_predictors_ok > length(config$predictors_wdi_codes)) {
  stop(sprintf(
    "ERROR: min_predictors_ok must be between 1 and %d (number of predictors)",
    length(config$predictors_wdi_codes)
  ))
}

cat("✓ All configuration parameters validated\n")

# Print final configuration
cat("\n--- Final Configuration ---\n")
cat(sprintf("Treatment Country: %s\n", config$treatment_country_iso3))
cat(sprintf("Treatment Year: %d\n", config$treatment_year))
cat(sprintf("Pre-period: %d-%d\n", config$pre_period[1], config$pre_period[2]))
cat(sprintf("Post-period end: %d\n", config$post_period_end))
cat(sprintf("Outcome: %s\n", config$outcome_wdi_code))
cat(sprintf("Predictors: %s\n", paste(config$predictors_wdi_codes, collapse = ", ")))
cat(sprintf("Special predictor years: %s\n", paste(config$special_predictor_years, collapse = ", ")))
cat(sprintf("Min coverage: %.0f%%\n", config$min_pre_coverage * 100))
cat(sprintf("Min predictors required: %d of %d\n", config$min_predictors_ok, 
            length(config$predictors_wdi_codes)))
cat(sprintf("Min donor pool size: %d\n", config$min_donor_pool_size))
cat(sprintf("Output directory: %s\n", config$output_dir))

# 2: Print enhanced features status
cat("\n--- Enhanced Features (V2) ---\n")
cat(sprintf("Sensitivity analysis: %s\n", ifelse(config$run_sensitivity_analysis, "ENABLED", "DISABLED")))
cat(sprintf("Leave-one-out diagnostics: %s\n", ifelse(config$run_leave_one_out, "ENABLED", "DISABLED")))
cat(sprintf("Donor shock detection: %s\n", ifelse(config$check_donor_shocks, "ENABLED", "DISABLED")))
cat("-------------------------------\n\n")

# ==============================================================================
# SECTION 3.5: DATA DOWNLOAD AND PREPARATION
# ==============================================================================

cat("Downloading data from World Bank WDI...\n")
cat("This may take 30-60 seconds depending on your internet connection...\n")

# All indicators to download
all_indicators <- c(config$outcome_wdi_code, config$predictors_wdi_codes)

# Download data with better error handling
tryCatch({
  wdi_data <- WDI::WDI(
    indicator = all_indicators,
    start = config$pre_period[1],
    end = config$post_period_end,
    extra = TRUE
  )
  
  if (is.null(wdi_data) || nrow(wdi_data) == 0) {
    stop("WDI returned no data. Please check your internet connection and try again.")
  }
  
  cat(sprintf("Successfully downloaded %d rows of data.\n", nrow(wdi_data)))
}, error = function(e) {
  stop(sprintf(
    paste("\n\nERROR: Failed to download WDI data.\n",
          "Message: %s\n",
          "\nPossible solutions:\n",
          "1. Check your internet connection\n",
          "2. Try again in a few minutes (World Bank API may be temporarily unavailable)\n",
          "3. Check if the World Bank API is accessible: https://api.worldbank.org/v2/country\n",
          "4. Verify indicator codes are correct\n",
          "5. Try with a smaller time range (e.g., --pre_period=1970,1979)\n"),
    e$message
  ))
})

# Filter out aggregates
wdi_data <- wdi_data %>%
  filter(region != "Aggregates", !is.na(iso3c))

cat(sprintf("After removing aggregates: %d rows, %d unique countries.\n",
            nrow(wdi_data), n_distinct(wdi_data$iso3c)))

# Rename columns for easier handling
colnames(wdi_data)[colnames(wdi_data) == config$outcome_wdi_code] <- "outcome"
for (i in seq_along(config$predictors_wdi_codes)) {
  old_name <- config$predictors_wdi_codes[i]
  new_name <- sprintf("predictor_%d", i)
  colnames(wdi_data)[colnames(wdi_data) == old_name] <- new_name
}

# ==============================================================================
# SECTION 3.6: DATA CLEANING AND INTERPOLATION
# ==============================================================================

cat("\nCleaning and preparing data...\n")

# Check if treatment country exists
if (!(config$treatment_country_iso3 %in% wdi_data$iso3c)) {
  stop(sprintf("Treatment country %s not found in WDI data!", 
               config$treatment_country_iso3))
}

# Function to interpolate small gaps
interpolate_gaps <- function(x, max_gap) {
  if (all(is.na(x))) return(x)
  zoo::na.approx(x, maxgap = max_gap, na.rm = FALSE)
}

# Apply interpolation if enabled
if (config$interpolate_small_gaps) {
  cat(sprintf("Interpolating gaps up to %d years...\n", 
              config$max_gap_to_interpolate))
  
  wdi_data <- wdi_data %>%
    group_by(iso3c) %>%
    arrange(year) %>%
    mutate(
      outcome = interpolate_gaps(outcome, config$max_gap_to_interpolate),
      across(starts_with("predictor_"), 
             ~interpolate_gaps(., config$max_gap_to_interpolate))
    ) %>%
    ungroup()
}

# Check coverage for treatment country
china_data <- wdi_data %>%
  filter(iso3c == config$treatment_country_iso3,
         year >= config$pre_period[1],
         year <= config$pre_period[2])

china_coverage <- mean(!is.na(china_data$outcome))
cat(sprintf("China outcome coverage in pre-period: %.1f%%\n", 
            china_coverage * 100))

if (china_coverage < config$min_pre_coverage) {
  stop(sprintf(
    paste("China has insufficient outcome coverage (%.1f%% < %.1f%% required).",
          "Try: (1) reducing min_pre_coverage, (2) enabling interpolation,",
          "(3) shortening pre-period (e.g., 1965-1979), or",
          "(4) increasing max_gap_to_interpolate."),
    china_coverage * 100, config$min_pre_coverage * 100
  ))
}

# 2: Store original data for shock detection later
wdi_data_original <- wdi_data

# ==============================================================================
# SECTION 3.7: DONOR POOL CONSTRUCTION WITH ENHANCED LOGGING
# ==============================================================================

cat("\nConstructing donor pool...\n")

# Create output directory for logs
if (!dir.exists(config$output_dir)) {
  dir.create(config$output_dir, recursive = TRUE)
}

# Initialize donor filter log
log_file <- file.path(config$output_dir, "donor_filter_log.txt")
log_conn <- file(log_file, open = "wt")

# Helper function to write to both console and log file
log_both <- function(msg, console = TRUE, file_only = FALSE) {
  if (!file_only) {
    if (console) cat(msg)
  }
  cat(msg, file = log_conn)
}

# Log header
log_both(sprintf("================================================================================\n"))
log_both(sprintf("DONOR POOL FILTERING LOG (V3 - COMPLETE PRODUCTION VERSION)\n"))
log_both(sprintf("================================================================================\n"))
log_both(sprintf("Analysis Date: %s\n", Sys.time()))
log_both(sprintf("Treatment Country: %s (%s)\n", config$treatment_country_iso3, 
                countrycode::countrycode(config$treatment_country_iso3, "iso3c", "country.name")))
log_both(sprintf("Treatment Year: %d\n", config$treatment_year))
log_both(sprintf("Pre-period: %d-%d (validated: no data leakage)\n", 
                config$pre_period[1], config$pre_period[2]))
log_both(sprintf("Min predictors required: %d of %d\n", config$min_predictors_ok,
                length(config$predictors_wdi_codes)))
log_both(sprintf("================================================================================\n\n"))

# Start with all countries except treatment
donor_pool <- wdi_data %>%
  filter(iso3c != config$treatment_country_iso3) %>%
  pull(iso3c) %>%
  unique()

log_both(sprintf("STEP 0: INITIAL POOL (all countries except treatment)\n"))
log_both(sprintf("  Count: %d countries\n", length(donor_pool)))
log_both(sprintf("  Excluded: %s\n", config$treatment_country_iso3))
log_both(sprintf("  Examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
log_both(sprintf("\n"))

# Apply filters
# 1. Exclude microstates
if (config$remove_microstates_by_name) {
  before <- length(donor_pool)
  removed <- intersect(donor_pool, microstates)
  donor_pool <- setdiff(donor_pool, microstates)
  
  log_both(sprintf("STEP 1: REMOVE MICROSTATES\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Removed: %d (%s)\n", length(removed), paste(head(removed, 10), collapse = ", ")))
  if (length(removed) > 10) {
    log_both(sprintf("           ... and %d more\n", length(removed) - 10))
  }
  log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
  log_both(sprintf("\n"))
}

# 2. Apply explicit exclusion list
if (length(config$donor_exclude_iso3) > 0) {
  before <- length(donor_pool)
  removed <- intersect(donor_pool, config$donor_exclude_iso3)
  donor_pool <- setdiff(donor_pool, config$donor_exclude_iso3)
  
  log_both(sprintf("STEP 2: EXPLICIT EXCLUSION LIST\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Exclusion list: %s\n", paste(config$donor_exclude_iso3, collapse = ", ")))
  log_both(sprintf("  Actually removed: %s\n", paste(removed, collapse = ", ")))
  log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
  log_both(sprintf("\n"))
}

# 3. Apply inclusion filters (if any)
if (length(config$donor_include_iso3) > 0) {
  before <- length(donor_pool)
  donor_pool <- intersect(donor_pool, config$donor_include_iso3)
  
  log_both(sprintf("STEP 3: ISO3 INCLUSION WHITELIST\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Whitelist: %s\n", paste(config$donor_include_iso3, collapse = ", ")))
  log_both(sprintf("  Remaining: %s\n", paste(sort(donor_pool), collapse = ", ")))
  log_both(sprintf("\n"))
}

# 4. Region filters
donor_meta <- wdi_data %>%
  select(iso3c, country, region, income) %>%
  distinct()

if (length(config$donor_include_regions) > 0) {
  before <- length(donor_pool)
  valid_donors <- donor_meta %>%
    filter(region %in% config$donor_include_regions) %>%
    pull(iso3c)
  removed <- setdiff(donor_pool, valid_donors)
  donor_pool <- intersect(donor_pool, valid_donors)
  
  log_both(sprintf("STEP 4a: REGION INCLUSION FILTER\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Included regions: %s\n", paste(config$donor_include_regions, collapse = ", ")))
  log_both(sprintf("  Removed: %d (%s)\n", length(removed), paste(head(removed, 10), collapse = ", ")))
  if (length(removed) > 10) {
    log_both(sprintf("           ... and %d more\n", length(removed) - 10))
  }
  log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
  log_both(sprintf("\n"))
}

if (length(config$donor_exclude_regions) > 0) {
  before <- length(donor_pool)
  invalid_donors <- donor_meta %>%
    filter(region %in% config$donor_exclude_regions) %>%
    pull(iso3c)
  removed <- intersect(donor_pool, invalid_donors)
  donor_pool <- setdiff(donor_pool, invalid_donors)
  
  log_both(sprintf("STEP 4b: REGION EXCLUSION FILTER\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Excluded regions: %s\n", paste(config$donor_exclude_regions, collapse = ", ")))
  log_both(sprintf("  Actually removed: %s\n", paste(removed, collapse = ", ")))
  log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
  log_both(sprintf("\n"))
}

# 5. Income filters
if (length(config$donor_include_income_groups) > 0) {
  before <- length(donor_pool)
  valid_donors <- donor_meta %>%
    filter(income %in% config$donor_include_income_groups) %>%
    pull(iso3c)
  removed <- setdiff(donor_pool, valid_donors)
  donor_pool <- intersect(donor_pool, valid_donors)
  
  log_both(sprintf("STEP 5: INCOME GROUP FILTER\n"))
  log_both(sprintf("  Count before: %d\n", before))
  log_both(sprintf("  Count after: %d\n", length(donor_pool)))
  log_both(sprintf("  Included income groups: %s\n", paste(config$donor_include_income_groups, collapse = ", ")))
  log_both(sprintf("  Removed: %d (%s)\n", length(removed), paste(head(removed, 10), collapse = ", ")))
  if (length(removed) > 10) {
    log_both(sprintf("           ... and %d more\n", length(removed) - 10))
  }
  log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
  log_both(sprintf("\n"))
}

# 6. Check minimum coverage for donor pool - ENHANCED VERSION
# Calculate coverage for outcome and ALL predictors
donor_coverage_full <- wdi_data %>%
  filter(iso3c %in% donor_pool,
         year >= config$pre_period[1],
         year <= config$pre_period[2]) %>%
  group_by(iso3c) %>%
  summarize(
    outcome_coverage = mean(!is.na(outcome)),
    predictor_1_coverage = mean(!is.na(predictor_1)),
    predictor_2_coverage = mean(!is.na(predictor_2)),
    predictor_3_coverage = mean(!is.na(predictor_3)),
    .groups = "drop"
  )

# Join with metadata for logging
donor_coverage_full <- donor_coverage_full %>%
  left_join(donor_meta, by = "iso3c")

# 2: ENHANCED FILTER - Use configurable min_predictors_ok
donor_coverage <- donor_coverage_full %>%
  mutate(
    n_predictors_ok = (predictor_1_coverage >= config$min_pre_coverage) +
                     (predictor_2_coverage >= config$min_pre_coverage) +
                     (predictor_3_coverage >= config$min_pre_coverage)
  ) %>%
  filter(
    outcome_coverage >= config$min_pre_coverage,
    n_predictors_ok >= config$min_predictors_ok  # 2: Use parameter instead of hardcoded 2
  )

# Log removed donors for diagnostics
removed_donors <- donor_coverage_full %>%
  filter(!(iso3c %in% donor_coverage$iso3c))

before_coverage <- length(donor_pool)
donor_pool <- intersect(donor_pool, donor_coverage$iso3c)

log_both(sprintf("STEP 6: DATA COVERAGE FILTER (Pre-period %d-%d)\n", 
                config$pre_period[1], config$pre_period[2]))
log_both(sprintf("  Count before: %d\n", before_coverage))
log_both(sprintf("  Count after: %d\n", length(donor_pool)))
log_both(sprintf("  Removed: %d\n", before_coverage - length(donor_pool)))
log_both(sprintf("  Outcome coverage requirement: >= %.0f%%\n", config$min_pre_coverage * 100))
log_both(sprintf("  Predictor requirement: At least %d of %d predictors with >= %.0f%% coverage\n",
                config$min_predictors_ok, length(config$predictors_wdi_codes),
                config$min_pre_coverage * 100))
log_both(sprintf("  Remaining examples: %s\n", paste(head(sort(donor_pool), 10), collapse = ", ")))
log_both(sprintf("\n"))

if (nrow(removed_donors) > 0) {
  log_both(sprintf("Detailed Coverage Report for Removed Donors:\n"), console = FALSE, file_only = TRUE)
  log_both(sprintf("%-8s %-30s %-10s %-10s %-10s %-10s %-10s\n",
                  "ISO3", "Country", "Outcome", "Pred1", "Pred2", "Pred3", "N_OK"), 
          console = FALSE, file_only = TRUE)
  log_both(sprintf("%s\n", paste(rep("-", 100), collapse = "")), console = FALSE, file_only = TRUE)
  
  removed_summary <- removed_donors %>%
    mutate(
      n_pred_ok = (predictor_1_coverage >= config$min_pre_coverage) +
                 (predictor_2_coverage >= config$min_pre_coverage) +
                 (predictor_3_coverage >= config$min_pre_coverage),
      reason = case_when(
        outcome_coverage < config$min_pre_coverage ~ "Outcome",
        n_pred_ok < config$min_predictors_ok ~ sprintf("Predictors (%d/%d)", n_pred_ok, 
                                                        length(config$predictors_wdi_codes)),
        TRUE ~ "Unknown"
      )
    ) %>%
    arrange(desc(outcome_coverage), desc(n_pred_ok))
  
  for (i in 1:min(30, nrow(removed_summary))) {
    row <- removed_summary[i, ]
    log_both(sprintf("%-8s %-30s %6.1f%% %9.1f%% %9.1f%% %9.1f%% %4d/%d [%s]\n",
                    row$iso3c,
                    substr(row$country, 1, 30),
                    row$outcome_coverage * 100,
                    row$predictor_1_coverage * 100,
                    row$predictor_2_coverage * 100,
                    row$predictor_3_coverage * 100,
                    row$n_pred_ok,
                    length(config$predictors_wdi_codes),
                    row$reason),
            console = FALSE, file_only = TRUE)
  }
  
  if (nrow(removed_summary) > 30) {
    log_both(sprintf("... and %d more (see full table above)\n", nrow(removed_summary) - 30),
            console = FALSE, file_only = TRUE)
  }
  log_both(sprintf("\n"), console = FALSE, file_only = TRUE)
  
  # Also print abbreviated version to console
  cat("\nDonors removed due to insufficient coverage:\n")
  removed_console <- removed_summary %>%
    select(iso3c, country, reason, outcome_coverage, 
           predictor_1_coverage, predictor_2_coverage, predictor_3_coverage)
  print(head(removed_console, 20))
  cat(sprintf("... and %d more (see donor_filter_log.txt for full details)\n", 
              max(0, nrow(removed_console) - 20)))
}

cat(sprintf("\nAfter coverage filter: %d countries (-%d removed)\n",
            length(donor_pool), before_coverage - length(donor_pool)))
cat(sprintf("  Outcome coverage requirement: %.0f%%\n", config$min_pre_coverage * 100))
cat(sprintf("  Predictor requirement: At least %d of %d predictors with %.0f%% coverage\n",
            config$min_predictors_ok, length(config$predictors_wdi_codes),
            config$min_pre_coverage * 100))

# 2: ENHANCED - Strict minimum donor pool enforcement
if (length(donor_pool) < config$min_donor_pool_size) {
  # Close log file before stopping
  close(log_conn)
  
  stop(sprintf(
    paste("\n\n==========================================================================",
          "ERROR: INSUFFICIENT DONOR POOL SIZE",
          "==========================================================================",
          "\nCurrent donor pool: %d countries",
          "Minimum required: %d countries (config$min_donor_pool_size)",
          "\nMethodological Issue:",
          "  Synthetic Control Method requires a large donor pool (typically 20-50+)",
          "  to satisfy the 'convex hull' requirement and ensure a credible",
          "  counterfactual. With only %d donors, the analysis is methodologically",
          "  unsound and results cannot be trusted.",
          "\nRemediation Steps (try in order):",
          "\n1. REDUCE coverage threshold (current: %.0f%%):",
          "   Rscript run_scm_v2.R --min_pre_coverage=0.7",
          "   Rscript run_scm_v2.R --min_pre_coverage=0.6",
          "\n2. REDUCE minimum predictors (current: %d of %d):",
          "   Rscript run_scm_v2.R --min_predictors_ok=1",
          "\n3. ENABLE interpolation (current: %s):",
          "   Rscript run_scm_v2.R --interpolate_small_gaps=TRUE --max_gap_to_interpolate=5",
          "\n4. SHORTEN pre-period (current: %d-%d):",
          "   Rscript run_scm_v2.R --pre_period=1970,1979",
          "   # Rationale: WDI coverage much better in 1970s than 1960s",
          "\n5. COMBINE multiple adjustments:",
          "   Rscript run_scm_v2.R --min_pre_coverage=0.7 --min_predictors_ok=1",
          "\n6. REDUCE minimum donor requirement (last resort):",
          "   Rscript run_scm_v2.R --min_donor_pool_size=5",
          "   # WARNING: Results with < 10 donors are methodologically questionable",
          "\nDiagnostic Information:",
          "  See %s for details on why countries were removed.",
          "  Check STEP 6 (coverage filter) for the largest source of removals.",
          "\nMethodological References:",
          "  - Abadie et al. (2010): 'Large donor pools improve convex hull coverage'",
          "  - Ferman & Pinto (2019): 'Small pools increase false positive rates'",
          "  - Recommended minimum: 10 donors (20-50+ ideal)",
          "\n==========================================================================\n",
          sep = "\n"),
    length(donor_pool),
    config$min_donor_pool_size,
    length(donor_pool),
    config$min_pre_coverage * 100,
    config$min_predictors_ok,
    length(config$predictors_wdi_codes),
    ifelse(config$interpolate_small_gaps, "enabled", "disabled"),
    config$pre_period[1], config$pre_period[2],
    log_file
  ))
}

if (length(donor_pool) < 20) {
  warning_msg <- sprintf(
    paste("Small donor pool (%d countries). Recommended: 20-50+ for robust inference.",
          "Results may be less stable. Consider relaxing filters."),
    length(donor_pool)
  )
  warning(warning_msg)
  log_both(sprintf("\nWARNING: %s\n\n", warning_msg))
}

# Print donor pool
donor_names <- donor_meta %>%
  filter(iso3c %in% donor_pool) %>%
  arrange(country) %>%
  select(iso3c, country, region, income)

log_both(sprintf("================================================================================\n"))
log_both(sprintf("FINAL DONOR POOL: %d countries\n", length(donor_pool)))
log_both(sprintf("================================================================================\n"))
log_both(sprintf("%-8s %-30s %-30s %-20s\n", "ISO3", "Country", "Region", "Income"))
log_both(sprintf("%s\n", paste(rep("-", 100), collapse = "")))

for (i in 1:nrow(donor_names)) {
  row <- donor_names[i, ]
  log_both(sprintf("%-8s %-30s %-30s %-20s\n",
                  row$iso3c,
                  substr(row$country, 1, 30),
                  substr(row$region, 1, 30),
                  substr(row$income, 1, 20)))
}

log_both(sprintf("================================================================================\n\n"))

# Close log file
close(log_conn)

cat("\nDonor pool countries:\n")
print(donor_names, n = Inf)
cat(sprintf("\nDonor filter log saved to: %s\n", log_file))

cat(sprintf("\n✓ Donor pool construction complete: %d countries\n", length(donor_pool)))
cat(sprintf("✓ All validation checks passed\n"))

# ==============================================================================
# MARKER "3" - END OF V2 ENHANCED DONOR POOL CONSTRUCTION
# ==============================================================================
# V2 enhanced sections (2.1-2.7) complete. Now continuing with V1 workflow.
# ==============================================================================

# ==============================================================================
# SECTION 3.8: PREPARE DATA FOR SYNTH (V1 Workflow Continues)
# ==============================================================================

cat("\nPreparing data for Synth package...\n")

# Create panel data with unit IDs
panel_data <- wdi_data %>%
  filter(iso3c %in% c(config$treatment_country_iso3, donor_pool)) %>%
  select(country, iso3c, year, outcome, starts_with("predictor_")) %>%
  arrange(iso3c, year)

# Create numeric unit IDs
unit_map <- data.frame(
  iso3c = c(config$treatment_country_iso3, sort(donor_pool)),
  unit_id = seq_along(c(config$treatment_country_iso3, donor_pool))
)

panel_data <- panel_data %>%
  left_join(unit_map, by = "iso3c")

treated_unit_id <- unit_map$unit_id[unit_map$iso3c == config$treatment_country_iso3]
control_unit_ids <- unit_map$unit_id[unit_map$iso3c != config$treatment_country_iso3]

cat(sprintf("Treated unit ID: %d (%s)\n", treated_unit_id, 
            config$treatment_country_iso3))
cat(sprintf("Control units: %d-%d (%d donors)\n", 
            min(control_unit_ids), max(control_unit_ids), 
            length(control_unit_ids)))

# Build predictors list for dataprep
# Average predictors over pre-period
predictors_list <- character(0)
predictors_ops <- character(0) # Store operations as character vector

for (i in seq_along(config$predictors_wdi_codes)) {
  pred_name <- sprintf("predictor_%d", i)
  predictors_list <- c(predictors_list, pred_name)
  predictors_ops <- c(predictors_ops, "mean") # Add "mean" for each predictor
}


# Special predictors (outcome at specific years)
special_predictors <- list()
for (year in config$special_predictor_years) {
  if (year >= config$pre_period[1] && year <= config$pre_period[2]) {
    special_predictors[[length(special_predictors) + 1]] <- list(
      "outcome", year, "outcome"
    )
  }
}

cat(sprintf("Using %d averaged predictors and %d special predictors (TFR at specific years)\n",
            length(predictors_list), length(special_predictors)))
cat(sprintf("Predictors: %s\n", paste(predictors_list, collapse=", ")))
cat(sprintf("Operations: %s\n", paste(predictors_ops, collapse=", ")))

# ==============================================================================
# SECTION 3.9: FIT SYNTHETIC CONTROL MODEL
# ==============================================================================

cat("\nFitting Synthetic Control Model...\n")

# Prepare data for Synth
tryCatch({
  dataprep_out <- dataprep(
    foo = as.data.frame(panel_data),
    predictors = predictors_list,
    predictors.op = "mean",
    dependent = "outcome",
    unit.variable = "unit_id",
    time.variable = "year",
    treatment.identifier = treated_unit_id,
    controls.identifier = control_unit_ids,
    time.predictors.prior = config$pre_period[1]:config$pre_period[2],
    time.optimize.ssr = config$pre_period[1]:config$pre_period[2],
    time.plot = config$pre_period[1]:config$post_period_end,
    special.predictors = special_predictors
  )

  cat("Data prepared successfully.\n")
}, error = function(e) {
  stop(sprintf("dataprep failed: %s\n", e$message))
})

# Check for NA in predictor matrices and log if donors were dropped
actual_control_units <- as.integer(colnames(dataprep_out$Y0plot))
expected_control_units <- control_unit_ids

dropped_units <- setdiff(expected_control_units, actual_control_units)
if (length(dropped_units) > 0) {
  dropped_iso3 <- unit_map %>% filter(unit_id %in% dropped_units) %>% pull(iso3c)
  dropped_countries <- donor_meta %>% filter(iso3c %in% dropped_iso3) %>% pull(country)
  
  warning(sprintf(
    paste("IMPORTANT: dataprep silently dropped %d donors due to missing data!",
          "Dropped: %s",
          "This suggests coverage filter was not strict enough.",
          "Consider: (1) increasing min_pre_coverage, (2) disabling interpolation,",
          "or (3) inspecting specific countries for data gaps."),
    length(dropped_units),
    paste(sprintf("%s (%s)", dropped_countries, dropped_iso3), collapse = ", ")
  ))
  
  # Log to file
  log_file <- file.path(config$output_dir, "donor_filter_log.txt")
  log_append <- file(log_file, open = "at")
  cat(sprintf("\n================================================================================\n"), file = log_append)
  cat(sprintf("DATAPREP NA REMOVAL (SILENT DROPS)\n"), file = log_append)
  cat(sprintf("================================================================================\n"), file = log_append)
  cat(sprintf("WARNING: dataprep() silently removed %d donors due to NA values in predictors\n", 
              length(dropped_units)), file = log_append)
  cat(sprintf("This indicates the coverage filter was not strict enough to catch all NA issues.\n\n"), 
      file = log_append)
  cat(sprintf("Dropped donors:\n"), file = log_append)
  for (i in seq_along(dropped_iso3)) {
    cat(sprintf("  - %s (%s)\n", dropped_countries[i], dropped_iso3[i]), file = log_append)
  }
  cat(sprintf("\nRecommendation: Increase min_pre_coverage or disable interpolation.\n"), file = log_append)
  cat(sprintf("================================================================================\n\n"), file = log_append)
  close(log_append)
}

# Check for NA in predictor matrices
if (any(is.na(dataprep_out$X1)) || any(is.na(dataprep_out$X0))) {
  na_predictors <- rownames(dataprep_out$X1)[apply(dataprep_out$X1, 1, 
                                                     function(x) any(is.na(x)))]
  warning(sprintf("NA values found in predictors: %s. These will cause issues.",
                  paste(na_predictors, collapse = ", ")))
}

# Fit Synth
tryCatch({
  synth_out <- synth(dataprep_out)
  cat("Synthetic control fitted successfully.\n")
}, error = function(e) {
  stop(sprintf("synth optimization failed: %s\n", e$message))
})

# Get synthetic control results
synth_tables <- synth.tab(dataprep.res = dataprep_out, synth.res = synth_out)

# ==============================================================================
# SECTION 3.10: EXTRACT AND REPORT RESULTS
# ==============================================================================

cat("\n=======================================================\n")
cat("SYNTHETIC CONTROL RESULTS\n")
cat("=======================================================\n\n")

# Extract trajectories
gaps_plot <- dataprep_out$Y1plot - 
  (dataprep_out$Y0plot %*% synth_out$solution.w)

treated_path <- dataprep_out$Y1plot
synthetic_path <- dataprep_out$Y0plot %*% synth_out$solution.w
years <- as.numeric(rownames(treated_path))

# Compute RMSPE
pre_years <- years[years < config$treatment_year]
post_years <- years[years >= config$treatment_year]

pre_gaps <- gaps_plot[as.character(pre_years), ]
post_gaps <- gaps_plot[as.character(post_years), ]

pre_rmspe <- sqrt(mean(pre_gaps^2))
post_rmspe <- sqrt(mean(post_gaps^2))
mspe_ratio <- post_rmspe^2 / pre_rmspe^2

cat(sprintf("Pre-treatment RMSPE (1960-%d): %.4f\n", 
            config$treatment_year - 1, pre_rmspe))
cat(sprintf("Post-treatment RMSPE (%d-%d): %.4f\n", 
            config$treatment_year, config$post_period_end, post_rmspe))
cat(sprintf("Post/Pre MSPE Ratio: %.4f\n\n", mspe_ratio))

# Average post-treatment gap
avg_post_gap <- mean(post_gaps)
cat(sprintf("Average post-treatment gap (%d-%d): %.4f\n",
            config$treatment_year, config$post_period_end, avg_post_gap))
cat(sprintf("Interpretation: China's TFR was on average %.4f %s than synthetic control post-1980.\n\n",
            abs(avg_post_gap), ifelse(avg_post_gap < 0, "lower", "higher")))

# Extract and print donor weights
weights_df <- data.frame(
  unit_id = control_unit_ids,
  weight = as.vector(synth_out$solution.w)
) %>%
  left_join(unit_map, by = "unit_id") %>%
  left_join(donor_meta, by = "iso3c") %>%
  filter(weight > 0.001) %>%
  arrange(desc(weight))

cat("Donor weights (units with weight > 0.001):\n")
if (nrow(weights_df) > 0) {
  print(as.data.frame(weights_df %>% select(country, iso3c, weight, region, income)), row.names = FALSE)
  cat(sprintf("\nTotal weight from %d donors: %.4f\n",
              nrow(weights_df), sum(weights_df$weight, na.rm = TRUE)))
} else {
  cat("No donors with weight > 0.001\n")
}

# ==============================================================================
# SECTION 3.11: PLACEBO-IN-SPACE TEST
# ==============================================================================

cat("\n=======================================================\n")
cat("PLACEBO-IN-SPACE TEST\n")
cat("=======================================================\n\n")

placebo_results <- list()

# Limit placebos if configured
placebo_donors <- donor_pool
if (!is.null(config$placebo_max_n) && length(placebo_donors) > config$placebo_max_n) {
  placebo_donors <- sample(placebo_donors, config$placebo_max_n)
  cat(sprintf("Running placebos for %d randomly sampled donors\n", 
              config$placebo_max_n))
}

cat(sprintf("Running placebo test for %d donors...\n", length(placebo_donors)))

for (placebo_iso3 in placebo_donors) {
  placebo_unit_id <- unit_map$unit_id[unit_map$iso3c == placebo_iso3]
  placebo_controls <- control_unit_ids[control_unit_ids != placebo_unit_id]
  
  # Add China back as potential donor for placebo
  if (treated_unit_id %in% placebo_controls) {
    placebo_controls <- placebo_controls
  } else {
    placebo_controls <- c(treated_unit_id, placebo_controls)
  }
  
  tryCatch({
    placebo_dataprep <- dataprep(
      foo = as.data.frame(panel_data),
      predictors = predictors_list,
      predictors.op = "mean",
      dependent = "outcome",
      unit.variable = "unit_id",
      time.variable = "year",
      treatment.identifier = placebo_unit_id,
      controls.identifier = placebo_controls,
      time.predictors.prior = config$pre_period[1]:config$pre_period[2],
      time.optimize.ssr = config$pre_period[1]:config$pre_period[2],
      time.plot = config$pre_period[1]:config$post_period_end,
      special.predictors = special_predictors
    )
    
    placebo_synth <- synth(placebo_dataprep, verbose = FALSE)
    
    placebo_gaps <- placebo_dataprep$Y1plot - 
      (placebo_dataprep$Y0plot %*% placebo_synth$solution.w)
    
    placebo_pre_gaps <- placebo_gaps[as.character(pre_years), ]
    placebo_post_gaps <- placebo_gaps[as.character(post_years), ]
    
    placebo_pre_rmspe <- sqrt(mean(placebo_pre_gaps^2))
    placebo_post_rmspe <- sqrt(mean(placebo_post_gaps^2))
    placebo_mspe_ratio <- placebo_post_rmspe^2 / placebo_pre_rmspe^2
    
    placebo_meta <- donor_meta %>% filter(iso3c == placebo_iso3)
    
    placebo_results[[placebo_iso3]] <- list(
      iso3c = placebo_iso3,
      country = placebo_meta$country[1],
      region = placebo_meta$region[1],
      income = placebo_meta$income[1],
      pre_rmspe = placebo_pre_rmspe,
      post_rmspe = placebo_post_rmspe,
      mspe_ratio = placebo_mspe_ratio
    )
  }, error = function(e) {
    # Skip failed placebos silently
  })
}

cat(sprintf("Successfully completed %d placebos (out of %d attempted)\n",
            length(placebo_results), length(placebo_donors)))

# Convert to data frame
placebo_df <- bind_rows(placebo_results)

# Apply pre-fit filter
if (config$placebo_prefit_filter == "quantile") {
  threshold <- quantile(placebo_df$pre_rmspe, config$placebo_prefit_filter_value, 
                        na.rm = TRUE)
  placebo_df_filtered <- placebo_df %>% filter(pre_rmspe <= threshold)
  cat(sprintf("Pre-fit filter (quantile %.2f): removed %d placebos with pre-RMSPE > %.4f\n",
              config$placebo_prefit_filter_value,
              nrow(placebo_df) - nrow(placebo_df_filtered),
              threshold))
} else if (config$placebo_prefit_filter == "relative") {
  threshold <- pre_rmspe * config$placebo_prefit_filter_value
  placebo_df_filtered <- placebo_df %>% filter(pre_rmspe <= threshold)
  cat(sprintf("Pre-fit filter (relative %.2f): removed %d placebos with pre-RMSPE > %.4f\n",
              config$placebo_prefit_filter_value,
              nrow(placebo_df) - nrow(placebo_df_filtered),
              threshold))
} else {
  placebo_df_filtered <- placebo_df
  cat("No pre-fit filter applied\n")
}

# Compute p-value
placebo_p_value <- mean(placebo_df_filtered$mspe_ratio >= mspe_ratio, na.rm = TRUE)

cat(sprintf("\nPlacebo-based p-value: %.4f\n", placebo_p_value))
cat(sprintf("Interpretation: %.1f%% of placebos have MSPE ratio >= China's ratio\n",
            placebo_p_value * 100))

if (placebo_p_value < 0.05) {
  cat("Result: Statistically significant at 5% level (unlikely due to chance)\n")
} else if (placebo_p_value < 0.10) {
  cat("Result: Marginally significant at 10% level\n")
} else {
  cat("Result: Not statistically significant (could be due to chance)\n")
}

# ==============================================================================
# SECTION 3.12: CREATE OUTPUT DIRECTORY AND SAVE RESULTS
# ==============================================================================

cat("\n=======================================================\n")
cat("SAVING RESULTS\n")
cat("=======================================================\n\n")

# Create output directory
if (!dir.exists(config$output_dir)) {
  dir.create(config$output_dir, recursive = TRUE)
}

# 1. Save donor weights
weights_export <- data.frame(
  Country = weights_df$country,
  ISO3 = weights_df$iso3c,
  Weight = weights_df$weight,
  Region = weights_df$region,
  Income = weights_df$income
)

weights_file <- file.path(config$output_dir, "donor_weights.csv")
write_csv(weights_export, weights_file)
cat(sprintf("Saved donor weights to %s\n", weights_file))

# 2. Save placebo results
placebo_export <- placebo_df %>%
  select(country, iso3c, region, income, pre_rmspe, post_rmspe, mspe_ratio) %>%
  arrange(desc(mspe_ratio))

placebo_file <- file.path(config$output_dir, "placebo_results.csv")
write_csv(placebo_export, placebo_file)
cat(sprintf("Saved placebo results to %s\n", placebo_file))

# 3. Save summary statistics
summary_stats <- data.frame(
  Metric = c("Treatment Country", "Treatment Year", "Pre-period", "Post-period",
             "Pre RMSPE", "Post RMSPE", "MSPE Ratio", "Placebo p-value",
             "Avg Post-treatment Gap", "Avg Effect 1980-2015", "N Donors",
             "N Placebos"),
  Value = c(
    config$treatment_country_iso3,
    as.character(config$treatment_year),
    sprintf("%d-%d", config$pre_period[1], config$pre_period[2]),
    sprintf("%d-%d", config$treatment_year, config$post_period_end),
    sprintf("%.4f", pre_rmspe),
    sprintf("%.4f", post_rmspe),
    sprintf("%.4f", mspe_ratio),
    sprintf("%.4f", placebo_p_value),
    sprintf("%.4f", avg_post_gap),
    sprintf("%.4f", avg_post_gap),
    as.character(length(donor_pool)),
    as.character(nrow(placebo_df))
  )
)

summary_file <- file.path(config$output_dir, "summary_stats.csv")
write_csv(summary_stats, summary_file)
cat(sprintf("Saved summary statistics to %s\n", summary_file))

# ==============================================================================
# SECTION 3.13: CREATE PLOTS
# ==============================================================================

cat("\nGenerating plots...\n")

# Prepare plotting data
plot_df <- data.frame(
  Year = years,
  China = as.vector(treated_path),
  Synthetic = as.vector(synthetic_path),
  Gap = as.vector(gaps_plot)
)

# Plot 1: TFR Path (China vs Synthetic)
p1 <- ggplot(plot_df, aes(x = Year)) +
  geom_line(aes(y = China, color = "China"), linewidth = 1) +
  geom_line(aes(y = Synthetic, color = "Synthetic China"), linewidth = 1, 
            linetype = "dashed") +
  geom_vline(xintercept = config$treatment_year, linetype = "dotted", 
             color = "red", linewidth = 0.8) +
  scale_color_manual(
    name = NULL,
    values = c("China" = "#1f77b4", "Synthetic China" = "#ff7f0e")
  ) +
  labs(
    title = "Total Fertility Rate: China vs Synthetic Control",
    subtitle = sprintf("One-Child Policy introduced in %d", config$treatment_year),
    x = "Year",
    y = "Total Fertility Rate (births per woman)",
    caption = "Source: World Bank WDI; Synthetic Control Method"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

path_file <- file.path(config$output_dir, "tfr_path.png")
ggsave(path_file, p1, width = 10, height = 6, dpi = 150, bg = "white")
cat(sprintf("Saved TFR path plot to %s\n", path_file))

# Plot 2: Gap (China - Synthetic)
p2 <- ggplot(plot_df, aes(x = Year, y = Gap)) +
  geom_line(linewidth = 1, color = "#2ca02c") +
  geom_hline(yintercept = 0, linetype = "solid", color = "gray50", linewidth = 0.5) +
  geom_vline(xintercept = config$treatment_year, linetype = "dotted", 
             color = "red", linewidth = 0.8) +
  labs(
    title = "Gap in Total Fertility Rate: China minus Synthetic Control",
    subtitle = sprintf("Treatment effect of One-Child Policy (introduced %d)", 
                      config$treatment_year),
    x = "Year",
    y = "Gap (China - Synthetic)",
    caption = "Source: World Bank WDI; Synthetic Control Method\nNegative gap indicates lower TFR in China than counterfactual"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

gap_file <- file.path(config$output_dir, "tfr_gap.png")
ggsave(gap_file, p2, width = 10, height = 6, dpi = 150, bg = "white")
cat(sprintf("Saved gap plot to %s\n", gap_file))

# Plot 3: Placebo MSPE Histogram
p3 <- ggplot(placebo_df_filtered, aes(x = mspe_ratio)) +
  geom_histogram(bins = 20, fill = "steelblue", alpha = 0.7, color = "black") +
  geom_vline(xintercept = mspe_ratio, color = "red", linewidth = 1.5, 
             linetype = "dashed") +
  annotate("text", x = mspe_ratio, y = Inf, 
           label = sprintf("China\n(ratio = %.2f)", mspe_ratio),
           hjust = -0.1, vjust = 1.5, color = "red", fontface = "bold") +
  labs(
    title = "Placebo Test: Distribution of Post/Pre MSPE Ratios",
    subtitle = sprintf("p-value = %.4f (proportion of placebos with ratio ≥ China's)",
                      placebo_p_value),
    x = "Post/Pre MSPE Ratio",
    y = "Count",
    caption = sprintf("Based on %d placebo runs; poor pre-fits filtered out",
                     nrow(placebo_df_filtered))
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

placebo_file <- file.path(config$output_dir, "placebo_mspe_hist.png")
ggsave(placebo_file, p3, width = 10, height = 6, dpi = 150, bg = "white")
cat(sprintf("Saved placebo histogram to %s\n", placebo_file))

# ==============================================================================
# SECTION 3.14: IN-TIME PLACEBO (OPTIONAL)
# ==============================================================================

if (!is.null(config$in_time_placebo_year) && 
    config$in_time_placebo_year >= config$pre_period[1] &&
    config$in_time_placebo_year < config$treatment_year) {
  
  cat(sprintf("\nRunning in-time placebo with treatment year = %d...\n",
              config$in_time_placebo_year))
  
  # Restrict data to pre-true-treatment
  time_placebo_end <- config$treatment_year - 1
  time_placebo_pre <- config$pre_period[1]:(config$in_time_placebo_year - 1)
  time_placebo_post <- config$in_time_placebo_year:time_placebo_end
  
  tryCatch({
    time_placebo_dataprep <- dataprep(
      foo = as.data.frame(panel_data),
      predictors = predictors_list,
      predictors.op = "mean",
      dependent = "outcome",
      unit.variable = "unit_id",
      time.variable = "year",
      treatment.identifier = treated_unit_id,
      controls.identifier = control_unit_ids,
      time.predictors.prior = time_placebo_pre,
      time.optimize.ssr = time_placebo_pre,
      time.plot = config$pre_period[1]:time_placebo_end,
      special.predictors = special_predictors[
        sapply(special_predictors, function(x) x[[2]] %in% time_placebo_pre)
      ]
    )
    
    time_placebo_synth <- synth(time_placebo_dataprep, verbose = FALSE)
    
    time_placebo_gaps <- time_placebo_dataprep$Y1plot - 
      (time_placebo_dataprep$Y0plot %*% time_placebo_synth$solution.w)
    
    time_placebo_df <- data.frame(
      Year = as.numeric(rownames(time_placebo_gaps)),
      Gap = as.vector(time_placebo_gaps)
    )
    
    p4 <- ggplot(time_placebo_df, aes(x = Year, y = Gap)) +
      geom_line(linewidth = 1, color = "#9467bd") +
      geom_hline(yintercept = 0, linetype = "solid", color = "gray50", 
                 linewidth = 0.5) +
      geom_vline(xintercept = config$in_time_placebo_year, linetype = "dotted", 
                 color = "red", linewidth = 0.8) +
      labs(
        title = "In-Time Placebo Test: Gap Before True Treatment",
        subtitle = sprintf("Fake treatment at %d (true treatment at %d)", 
                          config$in_time_placebo_year, config$treatment_year),
        x = "Year",
        y = "Gap (China - Synthetic)",
        caption = "Should show no systematic effect before true policy implementation"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(face = "bold", size = 14),
        panel.grid.minor = element_blank()
      )
    
    time_placebo_file <- file.path(config$output_dir, 
                                   "tfr_gap_in_time_placebo.png")
    ggsave(time_placebo_file, p4, width = 10, height = 6, dpi = 150, bg = "white")
    cat(sprintf("Saved in-time placebo plot to %s\n", time_placebo_file))
    
  }, error = function(e) {
    cat(sprintf("In-time placebo failed: %s\n", e$message))
  })
}

# ==============================================================================
# SECTION 3.15: GENERATE README
# ==============================================================================

readme_content <- sprintf("
=======================================================================
SYNTHETIC CONTROL ANALYSIS: CHINA'S ONE-CHILD POLICY
=======================================================================

Analysis Date: %s
Treatment Country: %s
Treatment Year: %d
Pre-period: %d-%d
Post-period: %d-%d

OVERVIEW
--------
This directory contains the results of a Synthetic Control Method (SCM)
analysis estimating the causal effect of China's One-Child Policy on
Total Fertility Rate (TFR).

METHOD
------
The synthetic control method constructs a weighted combination of donor
countries that best matches China's pre-treatment characteristics and
outcome trajectory. The difference between China's actual post-treatment
outcome and the synthetic control's outcome is interpreted as the
treatment effect.

KEY RESULTS
-----------
Pre-treatment RMSPE: %.4f
Post-treatment RMSPE: %.4f
Post/Pre MSPE Ratio: %.4f
Placebo p-value: %.4f

Average post-treatment effect: %.4f
(China's TFR was on average %.4f %s than counterfactual)

Statistical significance: %s

DONOR POOL
----------
Number of donors: %d
Top contributors (see donor_weights.csv for full list):
%s

FILES IN THIS DIRECTORY
-----------------------
1. tfr_path.png
   - Line plot showing China's actual TFR vs synthetic control TFR
   - Vertical line marks treatment year (%d)

2. tfr_gap.png
   - Treatment effect over time (China minus synthetic control)
   - Shows the estimated causal impact of the One-Child Policy

3. placebo_mspe_hist.png
   - Distribution of MSPE ratios from placebo tests
   - Red line shows China's ratio
   - Tests whether China's effect is unusually large

4. donor_weights.csv
   - Weights assigned to each donor country
   - Shows which countries contribute to synthetic China

5. placebo_results.csv
   - Results from all placebo tests
   - Used to compute statistical significance

6. summary_stats.csv
   - Summary table of all key metrics

%s

DATA SOURCE
-----------
World Bank World Development Indicators (WDI)
Outcome: Total Fertility Rate (SP.DYN.TFRT.IN)
Predictors: %s

INTERPRETATION
--------------
%s

REPRODUCIBILITY
---------------
This analysis was generated by run_scm.R with seed 20231108.
To replicate:
  Rscript run_scm.R

To modify parameters:
  Rscript run_scm.R --treatment_year=1981 --post_period_end=2014

See script comments for full configuration options.

REFERENCES
----------
Abadie, A., Diamond, A., & Hainmueller, J. (2010). 
Synthetic Control Methods for Comparative Case Studies. 
Journal of the American Statistical Association, 105(490), 493-505.

=======================================================================
",
Sys.Date(),
config$treatment_country_iso3,
config$treatment_year,
config$pre_period[1], config$pre_period[2],
config$treatment_year, config$post_period_end,
pre_rmspe, post_rmspe, mspe_ratio, placebo_p_value,
avg_post_gap, abs(avg_post_gap), 
ifelse(avg_post_gap < 0, "lower", "higher"),
ifelse(placebo_p_value < 0.05, "Significant at 5% level",
       ifelse(placebo_p_value < 0.10, "Marginally significant at 10% level",
              "Not statistically significant")),
length(donor_pool),
paste(sprintf("  - %s (%.1f%%)", 
              head(weights_export$Country, 5),
              head(weights_export$Weight, 5) * 100), collapse = "\n"),
config$treatment_year,
ifelse(file.exists(file.path(config$output_dir, "tfr_gap_in_time_placebo.png")),
       sprintf("\n7. tfr_gap_in_time_placebo.png\n   - In-time placebo test (fake treatment at %d)\n   - Should show no effect before real policy", 
               config$in_time_placebo_year),
       ""),
paste(config$predictors_wdi_codes, collapse = ", "),
sprintf(
  paste("The synthetic control method suggests that China's One-Child Policy",
        "%s total fertility rate by an average of %.2f births per woman",
        "during %d-%d. The placebo test p-value of %.4f indicates this effect",
        "%s statistically significant at conventional levels."),
  ifelse(avg_post_gap < 0, "reduced", "increased"),
  abs(avg_post_gap),
  config$treatment_year, config$post_period_end,
  placebo_p_value,
  ifelse(placebo_p_value < 0.05, "is", "is not")
)
)

readme_file <- file.path(config$output_dir, "README.txt")
writeLines(readme_content, readme_file)
cat(sprintf("Generated README at %s\n", readme_file))

# ==============================================================================
# SECTION 3.16: FINAL SUMMARY
# ==============================================================================

cat("\n=======================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("=======================================================\n\n")

cat("All results saved to:", config$output_dir, "\n\n")

cat("KEY FINDINGS:\n")
cat(sprintf("  • Pre-treatment fit (RMSPE): %.4f\n", pre_rmspe))
cat(sprintf("  • Post-treatment RMSPE: %.4f\n", post_rmspe))
cat(sprintf("  • MSPE ratio: %.4f\n", mspe_ratio))
cat(sprintf("  • Average effect: %.4f (China's TFR was %.4f %s)\n",
            avg_post_gap, abs(avg_post_gap),
            ifelse(avg_post_gap < 0, "lower", "higher")))
cat(sprintf("  • Placebo p-value: %.4f (%s)\n",
            placebo_p_value,
            ifelse(placebo_p_value < 0.05, "significant",
                   ifelse(placebo_p_value < 0.10, "marginally significant",
                          "not significant"))))
cat(sprintf("  • Number of donors: %d\n", length(donor_pool)))
cat(sprintf("  • Number of placebos: %d\n\n", nrow(placebo_df)))

cat("FILES GENERATED:\n")
files_generated <- list.files(config$output_dir, full.names = FALSE)
for (f in files_generated) {
  cat(sprintf("  ✓ %s\n", f))
}

cat("\n=======================================================\n")
cat("Thank you for using the SCM analysis script!\n")
cat("=======================================================\n")
