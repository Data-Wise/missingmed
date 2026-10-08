# Access the per-imputation mediation fits (for MBCO)

Returns the list of per-imputation **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects held in an
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md),
together with the number of imputations `m`.

## Usage

``` r
per_imputation_list(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
  object.

- ...:

  Unused.

## Value

A list with components `per_imputation` (a length-`m` list of named
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html))
and `m` (the number of imputations).

## Details

This accessor exists because **MBCO does not commute with Rubin's
rules**: D4-stacked MBCO needs the per-imputation fits, not the pooled
estimate. The list it returns is the shape consumed by
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)`(type = "mbco")`
and by an external
[`RMediation::mbco()`](https://data-wise.github.io/rmediation/reference/mbco.html)
MI entry point (missingmed issue \#2).

## See also

[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)

## Examples

``` r
set.seed(1)
n <- 150
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 25)] <- NA
imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
fit <- run(md)
pl <- per_imputation_list(fit)
pl$m
#> [1] 3
# The a path in each imputation, before pooling
vapply(pl$per_imputation, function(x) x@a_path, numeric(1))
#>         1         2         3 
#> 0.4541939 0.1483050 0.2966120 
```
