# Set up an SEM model with multiply imputed data.

This function sets up an SEM model with multiply imputed data for
analysis. The function accepts a
[mice::mids](https://amices.org/mice/reference/mids.html) object and a
model syntax for either
[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html) or
[OpenMx::OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html) and returns
a
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
object for analysis. It returns an error if the provided data is not a
[mice::mids](https://amices.org/mice/reference/mids.html) object or if
the specified SEM analysis method is not supported. It returns an object
of class
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md).

## Usage

``` r
set_sem(data, model, conf_int = FALSE, conf_level = 0.95)

# S4 method for class 'mids'
set_sem(data, model, conf_int = FALSE, conf_level = 0.95)
```

## Arguments

- data:

  A [mice::mids](https://amices.org/mice/reference/mids.html) object
  from the `mice` package containing multiply imputed datasets.

- model:

  A [lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html) or
  [OpenMx::OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html) model
  syntax to be used for SEM analysis. For `lavaan` models, the syntax
  should be a character string as described in
  [lavaan::model.syntax](https://rdrr.io/pkg/lavaan/man/model.syntax.html).
  For `OpenMx` models, the syntax should be an
  [OpenMx::mxModel](https://rdrr.io/pkg/OpenMx/man/mxModel.html) object
  with or without
  [`OpenMx::mxData()`](https://rdrr.io/pkg/OpenMx/man/mxData.html)
  specified; that is, `mxModel` syntax can be without data specified. In
  addition, both `lavaan` and `OpenMx` models can be a fitted model
  object in the respective package.

- conf_int:

  A logical value indicating whether confidence intervals are included
  in the SEM results. Defaults to `FALSE`.

- conf_level:

  A numeric value specifying the confidence level for confidence
  intervals, which must be between 0 and 1. Defaults to 0.95. If
  `conf_int` is `FALSE`, this argument is ignored.

## Value

An object of class SemImputedData. See
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
for the details of the slots.

## Details

The function technically constructs a new
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
object for structural equation modeling (SEM) analysis using either
[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html) or
[OpenMx::OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html) on multiply
imputed datasets. This function ensures that the provided data is a
[mice::mids](https://amices.org/mice/reference/mids.html) object from
the `mice` package and that the specified SEM analysis method is
supported.

All the arguments `data`, `method`, `conf_int`, and `conf_level` are
used to specify the SEM analysis. `set_sem` is a constructor function
for `SemImputedData` class. These methods are used as constructors for
the `SemImputedData` class.

## See also

[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
[mice::mids](https://amices.org/mice/reference/mids.html)
[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html)
[OpenMx::OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html)

## Examples

``` r
if (FALSE) { # \dontrun{
data("HolzingerSwineford1939", package = "lavaan")
df_complete <- na.omit(HolzingerSwineford1939)
amp <- mice::ampute(df_complete, prop = 0.2, mech = "MAR")
imputed_data <- mice::mice(amp$amp, m = 3, maxit = 3, seed = 12345, printFlag = FALSE)
model <- "
visual  =~ x1 + x2 + x3
textual =~ x4 + x5 + x6
speed   =~ x7 + x8 + x9"
sem_data <- set_sem(imputed_data, model)
str(sem_data)
} # }
```
