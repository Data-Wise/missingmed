# Get Number of Imputations from a mids Object

This function returns the number of imputations stored in a `mids`
object created by the `mice` package.

## Usage

``` r
n_imp(x)

# S4 method for class 'mids'
n_imp(x)
```

## Arguments

- x:

  A `mids` object representing multiple imputed datasets.

## Value

An integer representing the number of imputations.

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming `imputed_data` is a mids object created by the mice package
n_imp(imputed_data)
} # }
```
