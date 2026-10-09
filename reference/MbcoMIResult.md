# MbcoMIResult: D4-stacked MBCO test result (S7)

The value of `infer(<MDMediationFit>, type = "mbco")` and
[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md),
for the glm and the lavaan (maximum likelihood) engines alike. It is an
S7 object whose parent is `class_double`: its data is the named numeric
vector `c(D4, p, r4, nu, d_S)`, and the properties carry how it was
computed and the branch diagnostics.

## Usage

``` r
MbcoMIResult(
  .data = numeric(0),
  ariv = character(0),
  k = integer(0),
  m = integer(0),
  stacked_branch = character(0),
  branch_mix = logical(0),
  p_branch_a = integer(0)
)
```

## Arguments

- .data:

  Named numeric `c(D4, p, r4, nu, d_S)`.

- ariv:

  `"fixed"` or `"own"`: which per-imputation statistics fed `r4` (see
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)).

- k:

  Number of parameters the constraint removes (numerator df).

- m:

  Number of imputations pooled.

- stacked_branch:

  `"a"` or `"b"`: the branch (`a = 0` or `b = 0`) chosen by the
  constrained fit on the stacked data.

- branch_mix:

  Logical; `TRUE` when the imputations disagree on their own winning
  branch.

- p_branch_a:

  Share of imputations whose own winning branch is `a = 0`.

## Value

An `MbcoMIResult` S7 object.

## Details

- `D4`: the pooled statistic, referred to \\F(k, \nu)\\.

- `p`: its p-value.

- `r4`: the relative increase in variance, clamped at 0.

- `nu`: the denominator degrees of freedom (`Inf` when `r4` is 0).

- `d_S`: the MBCO statistic on the stacked data divided by the number of
  imputations.

`x["p"]`, `x[["p"]]` and `is.numeric(x)` work as they did on the plain
vector returned by missingmed 0.4.0 and earlier, and `S7::S7_data(x)`
returns that vector. Two things differ: `identical(x, old_vector)` is
`FALSE`, and `x$p` is an error.

## See also

[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)

## Examples

``` r
r <- MbcoMIResult(c(D4 = 4.7, p = 0.048, r4 = 1.16, nu = 13.8, d_S = 10.2),
  ariv = "fixed", k = 1, m = 5, stacked_branch = "b",
  branch_mix = TRUE, p_branch_a = 0.4
)
r[["p"]]
#> [1] 0.048
r@stacked_branch
#> [1] "b"
```
