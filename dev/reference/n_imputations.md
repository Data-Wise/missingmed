# Number of imputations

Number of imputations

## Usage

``` r
n_imputations(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
  or
  [MDMediationResult](https://data-wise.github.io/missingmed/dev/reference/MDMediationResult.md)
  object.

- ...:

  Unused.

## Value

Integer count of imputations.

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
n_imputations(fit)
#> [1] 3
n_imputations(pool(fit))
#> [1] 3
```
