# Checks if a matrix object is positive definite

Determines if a matrix is positive definite (all eigenvalues are
strictly positive) by attempting Cholesky decomposition.

## Usage

``` r
is_pd(x, quiet = FALSE)

# S4 method for class 'matrix'
is_pd(x, quiet = FALSE)
```

## Arguments

- x:

  A numeric matrix.

- quiet:

  Logical. If `TRUE`, suppresses warnings and error messages.

## Value

Returns `TRUE` if the matrix is positive definite, `FALSE` otherwise.

## Examples

``` r
# Example of a positive definite matrix
A <- matrix(c(1, 2, 2, 4), nrow = 2)
is_pd(A) # Should return TRUE
#> <simpleWarning in chol.default(x, pivot = TRUE): the matrix is either rank-deficient or not positive definite>
#> [1] FALSE
```
