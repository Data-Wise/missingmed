# Fit the mediation model across imputations

Runs the mediation specification held in an
[MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
object on every imputed dataset, delegating each fit to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).
The result is an
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
whose `per_imputation` slot is a list of **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects (one per imputation) — the shape consumed by both Rubin's-rules
pooling
([`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md))
and D4-stacked MBCO
([`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)).

## Usage

``` r
run(object, ...)
```

## Arguments

- object:

  An
  [MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
  object.

- ...:

  Additional arguments forwarded to
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).

## Value

An
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
object.

## Details

An engine error is rethrown with the engine and the imputation it failed
on. Engine warnings (a `glm` that did not converge, fitted probabilities
of 0 or 1) are collected and raised once, naming the imputations that
produced them.

It is the S7 successor of the S4
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md)
method.

## See also

[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md),
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md)

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
fit
#> <MDMediationFit>
#>   per-imputation fits: 3 named medfit::MediationData
#>   engine: glm 
#>   per-imputation a*b: mean = 0.0396 (range 0.0097 to 0.0663 )
#>   -> pool() for Rubin's-rules estimates; infer() for CIs / MBCO
```
