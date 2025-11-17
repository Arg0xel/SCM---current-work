# Quick Start Guide

Get up and running with the Synthetic Control analysis in **5 minutes**.

## ⚡ Lightning Start

> **⚠️ IMPORTANT**: Run this from your **terminal/command prompt**, NOT in an interactive R session!

```bash
# 1. Ensure R is installed (version 4.0+)
R --version

# 2. Run the analysis (packages install automatically)
Rscript run_scm.R

# 3. View results
ls scm_results/
```

**❌ Don't do this**: Opening R and typing `source("run_scm.R")` - this will hang!  
**✅ Do this**: Run `Rscript run_scm.R` from terminal

That's it! The script will:
- Download World Bank data automatically ✓
- Clean and prepare data ✓
- Fit synthetic control model ✓
- Run placebo tests ✓
- Generate plots and tables ✓
- Create auto-generated summary ✓

## 📊 What You'll Get

After running, check the `scm_results/` folder:

### Figures (PNG)
- **`tfr_path.png`** - Shows China vs Synthetic China fertility rates
- **`tfr_gap.png`** - Shows the treatment effect over time
- **`placebo_mspe_hist.png`** - Shows statistical significance

### Tables (CSV)
- **`donor_weights.csv`** - Countries used to create synthetic China
- **`placebo_results.csv`** - Statistical test results
- **`summary_stats.csv`** - Key numbers summary

### Summary
- **`README.txt`** - Auto-generated analysis report with interpretation

## 🎯 Key Results to Look For

**In the console output**:
```
Pre-treatment RMSPE: 0.XXX    # Lower is better (< 0.5 is good)
Post-treatment RMSPE: X.XXX
Post/Pre MSPE Ratio: X.XXX    # Larger means stronger effect
Placebo p-value: 0.XXX        # < 0.05 is statistically significant
Average post-treatment gap: -X.XXX  # Negative = China lower than counterfactual
```

**In the plots**:
- `tfr_path.png`: Synthetic line should closely follow actual line before 1980
- `tfr_gap.png`: Should show clear downward shift after 1980
- `placebo_mspe_hist.png`: Red line (China) should be in far right tail

## 🔧 Common Customizations

### Change treatment year
```bash
Rscript run_scm.R --treatment_year=1981
```

### Restrict to similar regions
```bash
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific,Latin America & Caribbean"
```

### End analysis in 2014
```bash
Rscript run_scm.R --post_period_end=2014
```

### Use manual donor pool
```bash
Rscript run_scm.R \
  --donor_include_iso3="KOR,THA,MYS,IDN,PHL,MEX,BRA,TUR"
```

## 📚 Next Steps

**For more examples**: See `EXAMPLES.sh` (28 ready-to-use commands)

**To customize thoroughly**: Edit `config.yaml` then run `Rscript run_scm.R`

**To validate results**: See `VALIDATION.md` for testing checklist

**For full documentation**: See `README.md` for comprehensive guide

**For installation help**: See `INSTALLATION.md` for platform-specific instructions

## ⚠️ Troubleshooting

### Error: "China has insufficient outcome coverage"
**Fix**: Enable interpolation
```bash
Rscript run_scm.R --interpolate_small_gaps=TRUE --max_gap_to_interpolate=5
```

### Error: "Very small donor pool"
**Fix**: Relax filters
```bash
Rscript run_scm.R --min_pre_coverage=0.7 --remove_microstates_by_name=FALSE
```

### Synth optimization fails
**Fix**: Try shorter pre-period
```bash
Rscript run_scm.R --pre_period=1965,1979
```

### R not found
**Fix**: Install R from https://cran.r-project.org/

## 💡 Tips

1. **First run**: Use defaults to see if the method is feasible
2. **Second run**: Try regional/income restrictions for robustness
3. **Third run**: Compare different treatment years (1979, 1980, 1981)
4. **Always check**: Pre-treatment fit quality (should be good!)

## 📖 Understanding the Output

### Pre-treatment fit (BEFORE policy)
- **RMSPE < 0.5**: Excellent fit ✓
- **RMSPE 0.5-1.0**: Acceptable fit ⚠️
- **RMSPE > 1.0**: Poor fit ✗ (be cautious interpreting results)

### Statistical significance
- **p-value < 0.05**: Significant (unlikely due to chance) ✓
- **p-value < 0.10**: Marginally significant ⚠️
- **p-value > 0.10**: Not significant ✗

### Effect magnitude (average post-treatment gap)
- **-0.3 to -0.5**: Moderate reduction in fertility
- **-0.5 to -1.0**: Large reduction
- **< -1.0**: Very large reduction

For China's One-Child Policy, expect:
- Good pre-fit (RMSPE ~0.3-0.5)
- Significant negative effect (p < 0.05)
- Moderate to large reduction (gap ~-0.3 to -0.8)

## 🚀 Advanced Usage

### Run multiple configurations
```bash
# Baseline
Rscript run_scm.R --output_dir="results_baseline"

# Regional
Rscript run_scm.R \
  --donor_include_regions="East Asia & Pacific" \
  --output_dir="results_regional"

# Income-matched
Rscript run_scm.R \
  --donor_include_income_groups="Upper middle income" \
  --output_dir="results_income"

# Compare
cat results_*/summary_stats.csv | grep "Avg Effect"
```

### Save output log
```bash
Rscript run_scm.R 2>&1 | tee analysis.log
```

### Run in background
```bash
nohup Rscript run_scm.R > analysis.log 2>&1 &
```

## ⏱️ Expected Runtime

| Task | Time |
|------|------|
| First run (with package install) | 3-5 minutes |
| Subsequent runs | 5-15 minutes |
| With restricted donor pool | 2-5 minutes |
| With many placebos (100+) | 10-20 minutes |

**Note**: Most time is spent on placebo tests. Use `--placebo_max_n=20` for faster exploratory runs.

## 🎓 For Students/Beginners

**What is Synthetic Control?**
- Creates a "fake China" from other countries
- This fake China shows what would have happened WITHOUT the policy
- Difference = effect of the policy

**How does it work?**
1. Finds countries similar to China before 1980
2. Combines them with optimal weights (like a weighted average)
3. Compares actual China to this synthetic China after 1980

**Why use it?**
- China is unique (can't compare to any single country)
- No obvious "control group"
- Flexible counterfactual (better than simple before/after)

**Key assumption**: Without policy, China would have followed same trend as synthetic China

## 📞 Getting Help

1. **Check console output** for specific error messages
2. **Read error suggestions** printed by the script
3. **See troubleshooting section** in README.md
4. **Try EXAMPLES.sh** for working commands
5. **Validate results** using VALIDATION.md checklist

## ✅ Success Checklist

After your first run, you should have:
- [x] Console output showing completion
- [x] `scm_results/` directory created
- [x] 3 PNG plots generated
- [x] 3 CSV files with data
- [x] 1 README.txt summary
- [x] No error messages

If all checked, congratulations! You've successfully run a Synthetic Control analysis. 🎉

---

**Version**: 1.0.0  
**Last updated**: 2025-11-17

**Ready to dive deeper?** → See `README.md` for comprehensive documentation
