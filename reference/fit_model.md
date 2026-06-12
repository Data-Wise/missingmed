# Fit a Structural Equation Model

Fits a structural equation model to provided data using either the
`lavaan` or `OpenMx` package.

## Usage

``` r
fit_model(model, data)
```

## Arguments

- model:

  A character string representing `lavaan` model syntax, a `lavaan`
  model object, or an
  [`OpenMx::MxModel`](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html)
  object.

- data:

  A data frame containing the data to which the model will be fitted.

## Value

A fitted model object from either `lavaan` or `OpenMx`, depending on the
input.

## Examples

``` r
if (FALSE) { # \dontrun{
data("HolzingerSwineford1939", package = "lavaan")
lav_model_syntax <- "visual =~ x1 + x2 + x3"
fitted_model <- fit_model(lav_model_syntax, HolzingerSwineford1939)
} # }
```
