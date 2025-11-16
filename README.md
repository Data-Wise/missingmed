# missingmed

<!-- badges: start -->
<!-- badges: end -->

## Overview

**missingmed** provides S4 classes and methods for conducting mediation analysis with multiply imputed datasets. The package integrates seamlessly with:

- **mice**: For multiple imputation of missing data
- **lavaan**: For structural equation modeling with latent variables
- **OpenMx**: For advanced SEM and path analysis
- **RMediation**: For computing confidence intervals of indirect effects

## Installation

You can install the development version of missingmed from GitHub:

```r
# install.packages("devtools")
devtools::install_github("Data-Wise/missingmed")
```

## Features

- **S4 Classes** for structured workflow:
  - `SemImputedData`: Container for multiply imputed data + SEM model
  - `SemResults`: Stores SEM fits across all imputations
  - `PooledSEMResults`: Pooled estimates using Rubin's rules

- **Methods**:
  - `set_sem()`: Set up SEM analysis with imputed data
  - `run_sem()`: Run SEM on each imputed dataset
  - `pool_sem()`: Pool results across imputations
  - `show()`, `summary()`, `print()`: S4 methods for clean output

- **Integration**: Works with both `lavaan` and `OpenMx` models

## Basic Usage

```r
library(missingmed)
library(mice)
library(lavaan)

# Load example data
data("HolzingerSwineford1939", package = "lavaan")

# Introduce missing data (for demonstration)
df_complete <- na.omit(HolzingerSwineford1939[paste0("x", 1:9)])
amp <- mice::ampute(df_complete, prop = 0.1, mech = "MAR")
data_with_missing <- amp$amp

# Perform multiple imputation
imputed_data <- mice(data_with_missing, m = 5, maxit = 10, seed = 12345, printFlag = FALSE)

# Define SEM model
model <- "
  visual  =~ x1 + x2 + x3
  textual =~ x4 + x5 + x6
  speed   =~ x7 + x8 + x9
"

# Analysis workflow
results <- imputed_data |>
  set_sem(model) |>      # Set up analysis
  run_sem() |>            # Run on each imputation
  pool_sem()              # Pool results

# View pooled results
results@tidy_table
```

## Integration with RMediation

The `missingmed` package is designed to work with `RMediation` for computing confidence intervals of indirect effects:

```r
library(RMediation)

# After pooling results, extract pooled estimates and covariance
pooled_coef <- results@tidy_table$estimate
pooled_cov <- results@cov_total

# Compute CI for indirect effect using RMediation
ci(mu = pooled_coef,
   Sigma = pooled_cov,
   quant = ~b1*b2*b3,  # Specify indirect effect
   type = "MC")
```

## Citation

If you use this package in your research, please cite:

```
Tofighi, D. (2024). missingmed: Mediation Analysis with Multiple Imputation for Missing Data.
R package version 0.1.0. https://github.com/Data-Wise/missingmed
```

## License

GPL-2

## Author

Davood Tofighi (dtofighi@gmail.com)

ORCID: 0000-0001-8523-7776
