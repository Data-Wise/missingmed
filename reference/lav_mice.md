# Fit SEM Model to Each Dataset in a MIDS Object Without Pooling

Fits a SEM model to each dataset in a `mids` object without pooling the
results. This function is an extension for the
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) function to
handle [mice::mids](https://amices.org/mice/reference/mids.html) objects
from the [mice::mice](https://amices.org/mice/reference/mice.html)
package. It allows for both a SEM model syntax as a character string or
a pre-fitted
[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html) model
object.

## Usage

``` r
lav_mice(model, mids, ...)
```

## Arguments

- model:

  Either a character string representing the SEM model to be fitted or a
  pre-fitted
  [lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html) model
  object.

- mids:

  A `mids` object from the
  [mice::mice](https://amices.org/mice/reference/mice.html) package.

- ...:

  Additional arguments to be passed to
  [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html).

## Value

A list of [lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html)
model fits, one for each imputed dataset.

## Author

Davood Tofighi <dtofighi@gmail.com>

## Examples

``` r
if (FALSE) { # \dontrun{
# library(mice)
# library(lavaan)
# Load Holzinger and Swineford (1939) dataset
data("HolzingerSwineford1939", package = "lavaan")
# Introduce missing data
df_complete <- na.omit(HolzingerSwineford1939)
amp <- mice::ampute(df_complete, prop = 0.2, mech = "MAR")
data_with_missing <- amp$amp

# Perform multiple imputation
imputed_data <- mice::mice(data_with_missing, m = 3, maxit = 5, seed = 12345, printFlag = FALSE)

# fit the Holzinger and Swineford (1939) example model
HS_model <- " visual  =~ x1 + x2 + x3
             textual =~ x4 + x5 + x6
             speed   =~ x7 + x8 + x9 "
# Fit the SEM model without running
fit_HS <- lavaan::sem(HS_model, data = data_with_missing, do.fit = FALSE)
# Fit the SEM model without pooling to each imputed dataset
fit_list1 <- lav_mice(HS_model, imputed_data)
# 'fit_list1' now contains a list of lavaan objects, one for each imputed dataset
# Fit the SEM model without pooling to each imputed dataset using a pre-fitted model object
fit_list2 <- lav_mice(fit_HS, imputed_data)
# 'fit_list2' now contains a list of lavaan objects, one for each imputed dataset
} # }
```
