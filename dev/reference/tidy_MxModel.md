# Tidy an MxModel Object

Extracts parameter estimates from an
[MxModel](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html) from the
[OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html) model and formats
them into a tidy dataframe.

## Usage

``` r
# S3 method for class 'MxModel'
tidy(x, conf_int = FALSE, conf_level = 0.95, ...)
```

## Arguments

- x:

  An object of class
  [MxModel](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html) resulting
  from an SEM fit using OpenMx.

- conf_int:

  Logical, whether to include confidence intervals in the output.

- conf_level:

  The confidence level to use for the confidence intervals.

- ...:

  Additional arguments (currently not used).

## Value

A tibble with one row per parameter and columns for parameter names,
estimates, standard errors, and optionally confidence intervals.

## See also

[OpenMx](https://rdrr.io/pkg/OpenMx/man/OpenMx.html)
[MxModel](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html)
[summary.MxModel](https://rdrr.io/pkg/OpenMx/man/summary.MxModel.html)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load Holzinger and Swineford (1939) dataset
data("HolzingerSwineford1939", package = "lavaan")
# Simple SEM model specification with OpenMx
manifestVars <- paste0("x", 1:9)
latVar <- c("visual", "textual", "speed")
model <- mxModel("Simple SEM",
  type = "RAM",
  manifestVars = manifestVars,
  latentVars = latVar,
  mxPath(from = "visual", to = c("x1", "x2", "x3")),
  mxPath(from = "textual", to = c("x4", "x5", "x6")),
  mxPath(from = "speed", to = c("x7", "x8", "x9")),
  mxPath(from = manifestVars, arrows = 2),
  mxPath(from = latVar, arrows = 2, free = FALSE, values = 1.0),
  mxPath(from = "one", to = manifestVars, arrows = 1, free = FALSE, values = 0),
  mxPath(from = "one", to = latVar, arrows = 1, free = FALSE, values = 0),
  mxData(HolzingerSwineford1939, type = "raw")
)
#
# Fit the model
fit0 <- mxRun(model)
tidy(fit0)
} # }
```
