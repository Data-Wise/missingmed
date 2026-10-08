# Get the number of imputations from a mids object

Returns the number of imputations `m` stored in a
[mice::mids](https://amices.org/mice/reference/mids.html) object.

## Usage

``` r
n_imp(x)
```

## Arguments

- x:

  A [mice::mids](https://amices.org/mice/reference/mids.html) object.

## Value

An integer: the number of imputations.

## Examples

``` r
imp <- mice::mice(mice::nhanes, m = 3, printFlag = FALSE, seed = 1)
n_imp(imp)
#> [1] 3
```
