# Determine If a SEM Model Has Been Fitted

This function checks whether a structural equation modeling (SEM) model,
represented by either a `lavaan` object or an `MxModel` object from the
`OpenMx` package, has been fitted. The function offers a convenient way
to programmatically verify if the model fitting step has been executed
for a given model object.

Method for ANY object. This method returns `FALSE` for any object that
is not a `lavaan` or `MxModel` object.

Method for lavaan objects. This method checks the `do.fit` option in the
`lavaan` object to determine if the model has been fitted. If the
`do.fit` option is `TRUE`, the model has been fitted; otherwise, it has
not been fitted.

Method for OpenMx objects. This method checks the `wasRun` slot in the
`MxModel` object to determine if the model has been fitted. If the
`wasRun` slot is `TRUE`, the model has been fitted; otherwise, it has
not been fitted.

## Usage

``` r
is_fit(model,...)

# S4 method for class 'ANY'
is_fit(model, ...)

# S4 method for class 'lavaan'
is_fit(model, ...)

# S4 method for class 'MxModel'
is_fit(model, ...)
```

## Arguments

- model:

  A lavaan object.

- ...:

  Additional arguments affecting the method dispatched (currently not
  used but available for future extensions).

## Value

A logical value: `TRUE` if the model has been fitted, and `FALSE`
otherwise.

## See also

[lavaan::lavaan](https://rdrr.io/pkg/lavaan/man/lavaan.html),
[OpenMx::MxModel](https://rdrr.io/pkg/OpenMx/man/MxModel-class.html)

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming 'lav_model' is a lavaan model object
lav_model_fit <- is_fit(lav_model)

# Assuming 'mx_model' is an OpenMx model object
mx_model_fit <- is_fit(mx_model)

# Checking the output
print(lav_model_fit)
print(mx_model_fit)
} # }
```
