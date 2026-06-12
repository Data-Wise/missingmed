# Function to check if lavaan model syntax is valid

This function checks if the lavaan model syntax is valid. It does so by
attempting to parse and fit the model in a safe environment. If the
model syntax is invalid, the function will return an error message.

## Usage

``` r
is_valid_lav_syntax(model, data = NULL)
```

## Arguments

- model:

  A character string representing the lavaan model to be fitted.

- data:

  A data frame containing the observed variables.

## Value

A logical value indicating whether the model syntax is valid.

## Author

Davood Tofighi <dtofighi@gmail.com>

## Examples

``` r
bad_model <- "y ~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9"
data(HolzingerSwineford1939, package = "lavaan")
is_valid_lav_syntax(bad_model, HolzingerSwineford1939)
#> [1] FALSE
good_model <- "visual =~ x1 + x2 + x3
textual =~ x4 + x5 + x6
speed =~ x7 + x8 + x9
visual ~ speed
textual ~ speed"
is_valid_lav_syntax(good_model, HolzingerSwineford1939)
#> [1] TRUE
```
