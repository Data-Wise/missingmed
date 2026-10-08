# Checks if a matrix object is positive definite

Determines if a symmetric matrix is positive definite (all eigenvalues
are strictly positive) by attempting Cholesky decomposition. A
non-symmetric matrix returns `FALSE`:
[`chol()`](https://rdrr.io/r/base/chol.html) reads only the upper
triangle, so it cannot judge one.

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
A <- matrix(c(2, 1, 1, 2), nrow = 2)
is_pd(A) # TRUE
#> [1] TRUE
# A singular (positive semi-definite) matrix is not positive definite
B <- matrix(c(1, 2, 2, 4), nrow = 2)
is_pd(B, quiet = TRUE) # FALSE
#> [1] FALSE
```
