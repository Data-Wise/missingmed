# Pool SEM Analysis Results

`pool_sem` pools SEM analysis results, supporting `lavaan` and `OpenMx`
models. It calculates pooled estimates, standard errors, confidence
intervals, and more.

This function pools the results of structural equation modeling (SEM)
analyses performed on multiple imputed datasets. It supports pooling for
models analyzed with either the `lavaan` or `OpenMx` package. The
function extracts and pools relevant statistics (e.g., estimates,
standard errors) across all imputations, considering the specified
confidence interval settings.

## Usage

``` r
pool_sem(object)

# S4 method for class 'SemResults'
pool_sem(object)
```

## Arguments

- object:

  `SemResults` object with SEM analysis results.

## Value

`PooledSEMResults` object containing pooled SEM analysis results.

A `data.frame` containing the pooled results of the SEM analyses. The
column names adhere to tidy conventions and include the following
columns:

- `term`: The name of the parameter being estimated.

- `estimate`: The pooled estimate of the parameter.

- `std_error`: The pooled standard error of the estimate.

- `statistic`: The pooled test statistic (e.g., z-value, t-value).

- `p_value`: The pooled p-value for the test statistic.

- `conf_low`: The lower bound of the confidence interval for the
  estimate.

- `conf_high`: The upper bound of the confidence interval for the
  estimate.

## Details

A generic function to pool SEM analysis results from multiple datasets
or imputations.

Refer to method-specific documentation for details on pooling process
and assumptions.

## See also

[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html),
[OpenMx::OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html)

## Author

Davood Tofighi <dtofighi@gmail.com>

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming `sem_results` is a SemResults object with lavaan model fits:
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
res_pooled <- imputed_data |>
  set_sem(model) |>
  run_sem() |>
  pool_sem()
res_pooled@tidy_table # Print the pooled results
} # }
```
