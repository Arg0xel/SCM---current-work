#!/usr/bin/env Rscript
################################################################################
# Synthetic Control Analysis: China's One-Child Policy Effect on TFR
# Author: Expert R Econometrics Engineer
# Date: 2025-11-17
# Reproducibility Seed: 20231108
################################################################################
#
# IMPORTANT: This script should be run from the command line using:
#   Rscript run_scm.R
#
# Do NOT source this file in an interactive R session, as it may hang during
# data download. If you must run interactively, run sections manually.
#
################################################################################

# ==============================================================================
# SECTION 1: SETUP AND CONFIGURATION
# ==============================================================================

# Check if running interactively and warn user
if (interactive()) {
  warning(
    paste("\n\n*** WARNING: You are running this script interactively! ***\n",
          "This script is designed to be run from command line with:\n",
          "  Rscript run_scm.R\n",
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

# --- Default Configuration ---
# All parameters are exposed here and can be overridden via config.yaml or CLI
config <- list(
  treatment_country_iso3 = "CHN",
  treatment_year = 1980,
  pre_period = c(1960, 1979),
  post_period_end = 2015,
  outcome_wdi_code = "SP.DYN.TFRT.IN",
  predictors_wdi_codes = c("NY.GDP.PCAP.KD", "SP.DYN.LE00.IN", "SP.URB.TOTL.IN.ZS"),
  special_predictor_years = c(1965, 1970, 1975, 1979),
  min_pre_coverage = 0.8,
  interpolate_small_gaps = TRUE,
  max_gap_to_interpolate = 3,
  donor_include_iso3 = c(),
  donor_exclude_iso3 = c("TWN", "HKG", "MAC"),
  donor_include_regions = c(),
  donor_include_income_groups = c(),
  donor_exclude_regions = c(),
  remove_microstates_by_name = TRUE,
  placebo_max_n = NULL,
  placebo_prefit_filter = "quantile",
  placebo_prefit_filter_value = 0.9,
  in_time_placebo_year = 1970,
  end_year_exclude_2015_policy_change = FALSE,
  output_dir = "scm_results"
)

# Microstates to potentially exclude
microstates <- c("LIE", "MCO", "SMR", "AND", "VAT", "NAU", "TUV", "PLW", 
                 "MHL", "KNA", "DMA", "VCT", "GRD", "ATG", "BRB", "TON",
                 "KIR", "FSM", "SYC", "MUS", "BHR", "MLT", "MDV")

# ==============================================================================
# SECTION 2: PACKAGE INSTALLATION AND LOADING
# ==============================================================================

cat("=======================================================\n")
cat("Synthetic Control Analysis: China One-Child Policy\n")
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
# SECTION 3: CONFIGURATION OVERRIDE LOGIC
# ==============================================================================

# Override with config.yaml if present
if (file.exists("config.yaml")) {
  cat("Found config.yaml, loading overrides...\n")
  if (require("yaml", quietly = TRUE)) {
    yaml_config <- yaml::read_yaml("config.yaml")
    for (key in names(yaml_config)) {
      if (key %in% names(config)) {
        config[[key]] <- yaml_config[[key]]
        cat(sprintf("  Overriding %s from YAML\n", key))
      }
    }
  } else {
    cat("yaml package not available; skipping config.yaml\n")
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
                        "placebo_max_n")) {
            config[[key]] <- as.integer(value)
          } else if (key %in% c("min_pre_coverage", "placebo_prefit_filter_value")) {
            config[[key]] <- as.numeric(value)
          } else if (key %in% c("interpolate_small_gaps", "remove_microstates_by_name",
                               "end_year_exclude_2015_policy_change")) {
            config[[key]] <- as.logical(toupper(value))
          } else if (key %in% c("donor_include_iso3", "donor_exclude_iso3", 
                               "donor_include_regions", "donor_include_income_groups",
                               "donor_exclude_regions", "predictors_wdi_codes")) {
            config[[key]] <- strsplit(value, ",")[[1]]
          } else if (key == "pre_period") {
            config[[key]] <- as.integer(strsplit(value, ",")[[1]])
          } else if (key == "special_predictor_years") {
            config[[key]] <- as.integer(strsplit(value, ",")[[1]])
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

# Print final configuration
cat("\n--- Final Configuration ---\n")
cat(sprintf("Treatment Country: %s\n", config$treatment_country_iso3))
cat(sprintf("Treatment Year: %d\n", config$treatment_year))
cat(sprintf("Pre-period: %d-%d\n", config$pre_period[1], config$pre_period[2]))
cat(sprintf("Post-period end: %d\n", config$post_period_end))
cat(sprintf("Outcome: %s\n", config$outcome_wdi_code))
cat(sprintf("Predictors: %s\n", paste(config$predictors_wdi_codes, collapse = ", ")))
cat(sprintf("Output directory: %s\n", config$output_dir))
cat("-------------------------------\n\n")

# ==============================================================================
# SECTION 4: DATA DOWNLOAD AND PREPARATION
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
# SECTION 5: DATA CLEANING AND INTERPOLATION
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

# ==============================================================================
# SECTION 6: DONOR POOL CONSTRUCTION
# ==============================================================================

cat("\nConstructing donor pool...\n")

# Start with all countries except treatment
donor_pool <- wdi_data %>%
  filter(iso3c != config$treatment_country_iso3) %>%
  pull(iso3c) %>%
  unique()

cat(sprintf("Initial pool: %d countries (excluding %s)\n", 
            length(donor_pool), config$treatment_country_iso3))

# Apply filters
# 1. Exclude microstates
if (config$remove_microstates_by_name) {
  before <- length(donor_pool)
  donor_pool <- setdiff(donor_pool, microstates)
  cat(sprintf("After removing microstates: %d countries (-%d)\n",
              length(donor_pool), before - length(donor_pool)))
}

# 2. Apply explicit exclusion list
if (length(config$donor_exclude_iso3) > 0) {
  before <- length(donor_pool)
  donor_pool <- setdiff(donor_pool, config$donor_exclude_iso3)
  cat(sprintf("After explicit exclusions: %d countries (-%d)\n",
              length(donor_pool), before - length(donor_pool)))
}

# 3. Apply inclusion filters (if any)
if (length(config$donor_include_iso3) > 0) {
  donor_pool <- intersect(donor_pool, config$donor_include_iso3)
  cat(sprintf("After ISO3 whitelist: %d countries\n", length(donor_pool)))
}

# 4. Region filters
donor_meta <- wdi_data %>%
  select(iso3c, country, region, income) %>%
  distinct()

if (length(config$donor_include_regions) > 0) {
  valid_donors <- donor_meta %>%
    filter(region %in% config$donor_include_regions) %>%
    pull(iso3c)
  donor_pool <- intersect(donor_pool, valid_donors)
  cat(sprintf("After region inclusion filter: %d countries\n", 
              length(donor_pool)))
}

if (length(config$donor_exclude_regions) > 0) {
  invalid_donors <- donor_meta %>%
    filter(region %in% config$donor_exclude_regions) %>%
    pull(iso3c)
  donor_pool <- setdiff(donor_pool, invalid_donors)
  cat(sprintf("After region exclusion filter: %d countries\n", 
              length(donor_pool)))
}

# 5. Income filters
if (length(config$donor_include_income_groups) > 0) {
  valid_donors <- donor_meta %>%
    filter(income %in% config$donor_include_income_groups) %>%
    pull(iso3c)
  donor_pool <- intersect(donor_pool, valid_donors)
  cat(sprintf("After income filter: %d countries\n", length(donor_pool)))
}

# 6. Check minimum coverage for donor pool
donor_coverage <- wdi_data %>%
  filter(iso3c %in% donor_pool,
         year >= config$pre_period[1],
         year <= config$pre_period[2]) %>%
  group_by(iso3c) %>%
  summarize(coverage = mean(!is.na(outcome)), .groups = "drop") %>%
  filter(coverage >= config$min_pre_coverage)

donor_pool <- intersect(donor_pool, donor_coverage$iso3c)

cat(sprintf("Final donor pool after coverage filter: %d countries\n", 
            length(donor_pool)))

if (length(donor_pool) < 5) {
  warning(sprintf(
    paste("Very small donor pool (%d countries). Consider:",
          "(1) relaxing filters, (2) reducing min_pre_coverage,",
          "(3) enabling interpolation, or (4) shortening pre-period."),
    length(donor_pool)
  ))
}

# Print donor pool
donor_names <- donor_meta %>%
  filter(iso3c %in% donor_pool) %>%
  arrange(country) %>%
  select(iso3c, country, region, income)

cat("\nDonor pool countries:\n")
print(donor_names, n = Inf)

# ==============================================================================
# SECTION 7: PREPARE DATA FOR SYNTH
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
predictors_list <- c()
predictors_ops_list <- c()

for (i in seq_along(config$predictors_wdi_codes)) {
  pred_name <- sprintf("predictor_%d", i)
  predictors_list <- c(predictors_list, pred_name)
  predictors_ops_list <- c(predictors_ops_list, "mean")
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

# ==============================================================================
# SECTION 8: FIT SYNTHETIC CONTROL MODEL
# ==============================================================================

cat("\nFitting Synthetic Control Model...\n")

# Prepare data for Synth
tryCatch({
  dataprep_out <- dataprep(
    foo = as.data.frame(panel_data),
    predictors = predictors_list,
    predictors.op = predictors_ops_list,
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
# SECTION 9: EXTRACT AND REPORT RESULTS
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
  weight = synth_out$solution.w
) %>%
  left_join(unit_map, by = "unit_id") %>%
  left_join(donor_meta, by = "iso3c") %>%
  filter(weight > 0.001) %>%
  arrange(desc(weight))

cat("Donor weights (units with weight > 0.001):\n")
print(weights_df %>% select(country, iso3c, weight, region, income), n = Inf)
cat(sprintf("\nTotal weight from %d donors: %.4f\n", 
            nrow(weights_df), sum(weights_df$weight)))

# ==============================================================================
# SECTION 10: PLACEBO-IN-SPACE TEST
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
      predictors = names(predictors_ops),
      predictors.op = unlist(predictors_ops),
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
# SECTION 11: CREATE OUTPUT DIRECTORY AND SAVE RESULTS
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
# SECTION 12: CREATE PLOTS
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
# SECTION 13: IN-TIME PLACEBO (OPTIONAL)
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
      predictors = names(predictors_ops),
      predictors.op = unlist(predictors_ops),
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
# SECTION 14: GENERATE README
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
# SECTION 15: FINAL SUMMARY
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
