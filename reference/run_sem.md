# Run a SEM model

A generic function to run and analyze multiply imputed data sets.

This method facilitates running SEM analysis using either lavaan or
OpenMx on multiply imputed datasets contained within a
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
object.

## Usage

``` r
run_sem(object, ...)

# S4 method for class 'SemImputedData'
run_sem(object, ...)
```

## Arguments

- object:

  A `SemImputedData` object

- ...:

  Additional arguments passed to either
  [lavaan::sem](https://rdrr.io/pkg/lavaan/man/sem.html) or
  [OpenMx::MxModel](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html).

## Value

A
[SemResults](https://data-wise.github.io/missingmed/reference/SemResults.md)
object

## Author

Davood Tofighi <dtofighi@gmail.com>

## Examples

``` r
if (FALSE) { # \dontrun{
library(RMediation)
# Load Holzinger and Swineford (1939) dataset
data("HolzingerSwineford1939", package = "lavaan")
# Introduce missing data
df_complete <- na.omit(HolzingerSwineford1939[paste0("x", 1:9)])
amp <- mice::ampute(df_complete, prop = 0.1, mech = "MAR")
data_with_missing <- amp$amp
# Perform multiple imputation
imputed_data <- mice::mice(data_with_missing, m = 3, maxit = 3, seed = 12345, printFlag = FALSE)
model <- "
 visual  =~ x1 + x2 + x3
 textual =~ x4 + x5 + x6
 speed   =~ x7 + x8 + x9
 "
res_sem <- imputed_data |>
  set_sem(model) |>
  run_sem()
res_sem@estimate_df # long tidy table of estimates across imputed datasets
} # }
```
