# Sensitivity analysis for departures from MAR

Every analysis in this package assumes the data are **missing at
random** (MAR): given what you observed, missingness does not depend on
the value that is missing. That assumption cannot be tested from the
data.
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
asks a different question: *if the missing values were systematically
higher or lower than MAR implies, how much would the conclusion change?*
It produces a sensitivity curve, not an estimate. Nothing it reports is
identified.

``` r

library(missingmed)
set.seed(1)
n <- 300
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[runif(n) < plogis(-1 + 0.8 * d$C)] <- NA
imp <- mice::mice(d, m = 5, method = "norm", printFlag = FALSE, seed = 1)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
```

## One shift

A shift `delta` is added to the imputed values of the `target` (the
mediator by default), in the variable’s own units, and the analysis is
repeated. A grid of shifts gives a curve; `delta = 0` is the MAR
analysis.

``` r

s <- sensitivity_mnar(md, delta = c(-0.5, 0, 0.5), n.mc = 2000, seed = 1)
tidy(s)
#> # A tibble: 3 × 7
#>       M    msp estimate conf_low conf_high mechanism scale
#>   <dbl>  <dbl>    <dbl>    <dbl>     <dbl> <chr>     <chr>
#> 1  -0.5 -0.309    0.154   0.0596     0.266 post      raw  
#> 2   0    0.191    0.153   0.0619     0.261 post      raw  
#> 3   0.5  0.691    0.138   0.0551     0.242 post      raw
```

Read `estimate`, `conf_low` and `conf_high` down the rungs: the indirect
effect and its interval at each delta. If the interval keeps the same
sign across a plausible range of deltas, the conclusion is robust to
that departure.

## `delta` is conditional; `msp` is what happened

`delta` is a **conditional** shift (given the observed predictors). The
column `msp` is the *marginal* difference actually realized between
imputed and observed values. Compare `msp` with what you meant: a
conditional shift of 0.5 does not make the marginal shift 0.5.

``` r

tidy(s)[, c("M", "msp")]
#> # A tibble: 3 × 2
#>       M    msp
#>   <dbl>  <dbl>
#> 1  -0.5 -0.309
#> 2   0    0.191
#> 3   0.5  0.691
```

## Choosing the range

There is no data-driven range. Choose deltas from substantive knowledge:
how different could the missing mediator values plausibly be from the
observed ones, in units of the mediator? Then report the whole curve.
`summary(s)` also finds a **tipping point** for a numeric grid: the
smallest shift at which the conclusion changes.

``` r

summary(s)
#> MNAR sensitivity curve -- mc | target: M 
#> 
#> # A tibble: 3 × 7
#>       M    msp estimate conf_low conf_high mechanism scale
#>   <dbl>  <dbl>    <dbl>    <dbl>     <dbl> <chr>     <chr>
#> 1  -0.5 -0.309    0.154   0.0596     0.266 post      raw  
#> 2   0    0.191    0.153   0.0619     0.261 post      raw  
#> 3   0.5  0.691    0.138   0.0551     0.242 post      raw  
#> 
#> No tipping point within the supplied grid.
```

Here no shift in the grid changes the conclusion, which is the
reassuring outcome: the interval keeps its sign across the whole range
tried.

## Several variables at once

Pass a data frame of shifts, one column per variable. Leave `target` as
`NULL`; the column names are the targets.

``` r

sensitivity_mnar(md, delta = data.frame(M = c(0, 0.5)), n.mc = 2000, seed = 1)
#> <MDSensitivityResult>  MNAR sensitivity curve
#>   target(s): M | rungs: 2 | inference: mc 
#>   seed: 1 (from argument) | target imputed by: norm 
#>   delta applied by: post (raw units) 
#> # A tibble: 2 × 7
#>       M   msp estimate conf_low conf_high mechanism scale
#>   <dbl> <dbl>    <dbl>    <dbl>     <dbl> <chr>     <chr>
#> 1   0   0.191    0.153   0.0619     0.261 post      raw  
#> 2   0.5 0.691    0.138   0.0551     0.242 post      raw  
#> 
#>   delta is a CONDITIONAL sensitivity parameter; `msp` is the marginal
#>   difference actually realized. Compare msp against what you intended.
#>   Assumes the supplied imputation model is compatible with the
#>   mediation model; this is not verifiable from here.
```

(One column here because only `M` has missing values in this example;
with several incomplete variables, add one column per variable.)

## A shift that depends on a covariate

`ums` replaces `delta` with a covariate-varying offset, passed to
`mice`’s NARFCS imputation methods. Each string is one rung and needs
exactly one intercept term, for example `"0.5 + 0.2*C"`: the offset is
`0.5 + 0.2 C` for each row. A `ums` grid has no numeric order, so
[`summary()`](https://rdrr.io/r/base/summary.html) computes no tipping
point for it.

``` r

sensitivity_mnar(md, ums = c("0", "0.5 + 0.2*C"), n.mc = 2000)
```

## A test per rung

`type = "mbco"` runs the D4 test at each delta instead of the interval.
The tipping point is then the delta at which the test stops rejecting.

``` r

sensitivity_mnar(md, delta = c(-0.5, 0, 0.5), type = "mbco")
```

## What it assumes, and what it does not cover

- The imputation model you supplied is compatible with the mediation
  model. That is not verifiable.
- The seed is pinned across rungs (`seed`, defaulting to the one stored
  in the `mids` object), so differences between rungs are the delta, not
  Monte Carlo noise.
- `method = "mi"` only. IPW has no imputed values to shift.
- With `engine = "lavaan"`, `type = "mc"` works. A latent mediator needs
  an explicit observed `target`; see the *Structural equation models*
  article.
