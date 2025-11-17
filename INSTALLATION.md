# Installation Guide

## Prerequisites

### R Installation

**Required**: R version 4.0.0 or higher

#### Windows
1. Download R from [CRAN](https://cran.r-project.org/bin/windows/base/)
2. Run the installer
3. Optionally install [RStudio Desktop](https://posit.co/download/rstudio-desktop/)

#### macOS
```bash
# Using Homebrew
brew install r

# Or download from CRAN
# https://cran.r-project.org/bin/macosx/
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install r-base r-base-dev

# Additional dependencies for package compilation
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev
```

#### Linux (CentOS/RHEL/Fedora)
```bash
sudo yum install R
# or
sudo dnf install R

# Additional dependencies
sudo yum install libcurl-devel openssl-devel libxml2-devel
```

### Verify Installation

```bash
R --version
```

You should see output like:
```
R version 4.x.x (YYYY-MM-DD) -- "Release Name"
```

## Package Installation

### Automatic (Recommended)

The script will automatically install all required packages on first run:

```bash
Rscript run_scm.R
```

### Manual Installation

If you prefer to install packages manually or want to pre-install them:

```r
# Open R console or RStudio
install.packages(c(
  "Synth",        # Synthetic Control Method
  "WDI",          # World Bank data API
  "dplyr",        # Data manipulation
  "tidyr",        # Data tidying
  "readr",        # Data reading/writing
  "ggplot2",      # Plotting
  "countrycode",  # Country code conversion
  "zoo",          # Time series utilities
  "scales"        # Plot scaling
), dependencies = TRUE)
```

### Verify Package Installation

```r
# Check that all packages load successfully
packages <- c("Synth", "WDI", "dplyr", "tidyr", "readr", 
              "ggplot2", "countrycode", "zoo", "scales")

for (pkg in packages) {
  if (require(pkg, character.only = TRUE)) {
    cat(sprintf("✓ %s loaded successfully\n", pkg))
  } else {
    cat(sprintf("✗ %s failed to load\n", pkg))
  }
}
```

## Optional: Using renv for Reproducibility

For maximum reproducibility, you can use `renv` to create a project-specific library:

### 1. Install renv

```r
install.packages("renv")
```

### 2. Initialize renv in project directory

```r
# In R console, navigate to project directory
setwd("/path/to/webapp")

# Initialize renv
renv::init()

# Install required packages
install.packages(c("Synth", "WDI", "dplyr", "tidyr", "readr", 
                   "ggplot2", "countrycode", "zoo", "scales"))

# Take snapshot of installed packages
renv::snapshot()
```

### 3. Restore environment on another machine

```r
# In project directory
renv::restore()
```

This creates a `renv.lock` file that records exact package versions.

## Troubleshooting

### Issue: Package compilation fails on Linux

**Solution**: Install development tools and libraries

**Ubuntu/Debian**:
```bash
sudo apt-get install build-essential gfortran
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev
```

**CentOS/RHEL**:
```bash
sudo yum groupinstall "Development Tools"
sudo yum install libcurl-devel openssl-devel libxml2-devel
```

### Issue: WDI package fails to download data

**Problem**: Network issues or World Bank API changes

**Solution**:
1. Check internet connection
2. Try updating WDI package: `install.packages("WDI")`
3. Check World Bank API status: [https://datahelpdesk.worldbank.org/](https://datahelpdesk.worldbank.org/)

### Issue: "Error in synth()" during optimization

**Problem**: Optimization algorithm fails to converge

**Possible causes**:
- Poor data quality (many missing values)
- Very small donor pool
- Incompatible constraints

**Solutions**:
1. Enable interpolation in config: `interpolate_small_gaps: TRUE`
2. Increase `max_gap_to_interpolate` to 5
3. Reduce `min_pre_coverage` to 0.7
4. Expand donor pool by relaxing filters
5. Try shorter pre-period: `pre_period: [1965, 1979]`

### Issue: "Package 'X' is not available"

**Problem**: Package not on CRAN or requires different repository

**Solution**:
```r
# Specify repository explicitly
install.packages("packagename", repos = "https://cloud.r-project.org/")

# Or install from GitHub (requires devtools)
install.packages("devtools")
devtools::install_github("username/packagename")
```

### Issue: Permission denied when writing results

**Problem**: No write permission in output directory

**Solution**:
```bash
# Check current directory
pwd

# Ensure you have write permissions
mkdir -p scm_results
chmod 755 scm_results

# Or specify different output directory
Rscript run_scm.R --output_dir="/path/with/write/permission"
```

## System Requirements

### Minimum Requirements
- **RAM**: 4 GB (8 GB recommended)
- **Disk Space**: 500 MB (for R, packages, and results)
- **Internet**: Required for downloading World Bank data
- **Operating System**: Windows 10+, macOS 10.13+, Linux (any recent distribution)

### Recommended Setup
- **RAM**: 8+ GB
- **CPU**: Multi-core processor (for faster placebo tests)
- **Disk Space**: 1 GB
- **R Version**: 4.2.0 or higher

## Performance Notes

### Typical Runtime
- **Default analysis**: 5-15 minutes
  - Data download: 30-60 seconds
  - Main SCM fit: 10-30 seconds
  - Placebo tests: 4-12 minutes (depends on donor pool size)
  - Plot generation: 5-10 seconds

### Speeding Up Analysis
1. **Limit placebos**: `--placebo_max_n=50`
2. **Restrict donor pool**: Use regional or income filters
3. **Parallel processing**: Not currently implemented, but placebos are independent

### Memory Usage
- **Typical**: 200-500 MB
- **Large donor pool (100+ countries)**: Up to 1 GB

## Next Steps

After installation, proceed to:
1. **Run default analysis**: `Rscript run_scm.R`
2. **Review outputs**: Check `scm_results/` directory
3. **Read auto-generated README**: `scm_results/README.txt`
4. **Customize**: Edit `config.yaml` or use CLI arguments

See `README.md` for detailed usage instructions and examples.
