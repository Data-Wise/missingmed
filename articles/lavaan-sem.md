# Structural equation models: the lavaan engine

`set_md_mediation(engine = "lavaan")` runs a structural equation model
on every imputed dataset and pools the result with Rubin’s rules. Use it
when the mediator is **latent** (measured by several indicators), when
you want a lavaan-specific option such as a robust estimator, or when
the model is easier to state as lavaan syntax than as two formulas. For
one observed mediator and a regression outcome the default
`engine = "glm"` is simpler.

This tutorial builds up from an observed path model to a latent
mediator.

## Data

An exposure `X`, a covariate `C`, a latent mediator measured by three
noisy indicators, and an outcome `Y`. Two of the indicators have missing
values.

``` r

library(missingmed)
set.seed(51)
n <- 300
C <- rnorm(n)
X <- rbinom(n, 1, 0.5)
L <- 0.6 * X + 0.3 * C + rnorm(n)            # the latent mediator
d <- data.frame(
  X, C,
  m1 = L + rnorm(n, 0, 0.5),
  m2 = 0.8 * L + rnorm(n, 0, 0.5),
  m3 = 0.7 * L + rnorm(n, 0, 0.5)
)
d$Y <- 0.2 * X + 0.5 * L + 0.3 * C + rnorm(n)
d$m1[1:40] <- NA
d$m2[41:70] <- NA
imp <- suppressWarnings(
  mice::mice(d, m = 5, method = "norm", printFlag = FALSE, seed = 2)
)
```

## An observed path model

Give the lavaan syntax in `model`, and name the three roles. `outcome`
is required: it must be regressed on the mediator in `model`. (If two
variables were regressed on the mediator, medfit would silently take the
first, so missingmed asks you to say which.)

``` r

d$Mobs <- (d$m1 + d$m2 + d$m3) / 3
imp_obs <- suppressWarnings(
  mice::mice(d, m = 5, method = "norm", printFlag = FALSE, seed = 2)
)
md_obs <- set_md_mediation(imp_obs,
  model = "Mobs ~ a * X + C\nY ~ b * Mobs + cp * X + C",
  treatment = "X", mediator = "Mobs", outcome = "Y",
  engine = "lavaan"
)
md_obs
#> <MDMediationData>
#>   estimator (method): mi | mechanism: mar 
#>   imputations (m)   : 5 
#>   treatment / mediator: X / Mobs 
#>   outcome: Y 
#>   lavaan model:
#>     Mobs ~ a * X + C
#>     Y ~ b * Mobs + cp * X + C
#>   engine: lavaan
```

The model is checked before anything is fitted: the syntax must parse,
the three roles must be distinct, `mediator ~ treatment` and
`outcome ~ mediator` must be in the model, and every observed variable
must be a column of the data.

``` r

res_obs <- pool(run(md_obs))
res_obs
#> <MDMediationResult> (pooled, Rubin's rules; m = 5 )
#>     term  estimate   std_error
#>        a 0.5625950 0.102205867
#>        b 0.5178868 0.068891519
#>  c_prime 0.2318642 0.004089056
#>   indirect effect a*b = 0.2914 
#>   -> infer(type = "mc") for the indirect-effect CI
```

The pooled `a`, `b` and `c_prime` equal what `engine = "glm"` gives on
the same imputations; see the *Reading the results* article for the
columns.

## A latent mediator

Put the measurement model in the syntax and name the latent variable as
the `mediator`. It is not a data column, and that is fine.

``` r

mod_lat <- "
  Mlat =~ m1 + m2 + m3
  Mlat ~ a * X + C
  Y    ~ b * Mlat + cp * X + C
"
md_lat <- set_md_mediation(imp,
  model = mod_lat,
  treatment = "X", mediator = "Mlat", outcome = "Y",
  engine = "lavaan"
)
fit_lat <- run(md_lat)
res_lat <- pool(fit_lat)
res_lat@tidy_table[, c("term", "estimate", "std_error", "statistic", "p_value")]
#>          term  estimate  std_error statistic      p_value
#> 1    Mlat=~m2 0.8337145 0.05124505 16.269170 2.123935e-17
#> 2    Mlat=~m3 0.6809994 0.03948628 17.246482 8.649068e-64
#> 3           a 0.6958945 0.12551235  5.544430 3.014538e-08
#> 4      Mlat~C 0.2392314 0.06616842  3.615493 3.024504e-04
#> 5           b 0.4861503 0.06520255  7.456001 1.084912e-13
#> 6          cp 0.1848040 0.12723510  1.452461 1.463803e-01
#> 7         Y~C 0.3667407 0.06490821  5.650143 1.614135e-08
#> 8      m1~~m1 0.3053363 0.05245582        NA           NA
#> 9      m2~~m2 0.2101666 0.03350157        NA           NA
#> 10     m3~~m3 0.2923506 0.03095271        NA           NA
#> 11       Y~~Y 1.0303279 0.08692134        NA           NA
#> 12 Mlat~~Mlat 1.0108630 0.11183901        NA           NA
#> 13    c_prime 0.1848040 0.01229161 15.034967 1.140356e-04
```

Two things to read in that table:

- The pooled **loadings** (`Mlat=~m2`, `Mlat=~m3`), with `m1` fixed to 1
  by lavaan’s default scaling, and the structural paths `a`, `b`, `cp`.
- The **variance rows** (`m1~~m1`, `Mlat~~Mlat`, …) keep their estimate
  and standard error, but `statistic` and `p_value` are `NA`. A variance
  is tested against zero, which is on the boundary of its range, so a
  Wald z-test is not valid there. A covariance between two different
  variables (for example a residual covariance `Y~~Y2`) has an interior
  null, so it keeps its test.

The indirect effect and its Monte Carlo interval:

``` r

set.seed(1)
infer(fit_lat, type = "mc", n.mc = 20000)
#> $CI
#> [1] 0.2018377 0.4949978
#> 
#> $Estimate
#> [1] 0.3383003
#> 
#> $SE
#> [1] 0.07545181
#> 
#> $MC.Error
#> [1] 0.0005335249
```

## Passing options to lavaan

`fit_args` is a named list of extra arguments for
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html). It is stored
on the object, so every later refit (including the ones inside
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md))
uses it. `model` and `data` cannot be overridden.

``` r

md_mlr <- set_md_mediation(imp,
  model = mod_lat, treatment = "X", mediator = "Mlat", outcome = "Y",
  engine = "lavaan", fit_args = list(estimator = "MLR")
)
md_mlr@fit_args
#> $estimator
#> [1] "MLR"
```

## What happens when a fit goes wrong

- **Non-convergence** in any imputation stops
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  once, naming every imputation that failed. Simplify the model, or
  raise the iteration limit with
  `fit_args = list(control = list(iter.max = 5000))`.
- A **converged but improper solution** (for example a negative residual
  variance) is a warning, raised once and naming the imputations.
  Pooling goes on: inspect those imputations before trusting the result.

## Inverse probability weighting with lavaan

`method = "ipw"` also works with the lavaan engine. The complete cases
are fitted with `sampling.weights`, and the standard errors are always
robust (sandwich), as for the glm path. A request for model-based
standard errors is refused rather than silently replaced:

``` r

set_md_mediation(d,
  model = "Mobs ~ a * X + C\nY ~ b * Mobs + cp * X + C",
  treatment = "X", mediator = "Mobs", outcome = "Y",
  engine = "lavaan", method = "ipw",
  fit_args = list(se = "standard")
)
#> Error:
#> ! `fit_args$se` = "standard" is not allowed for method = "ipw": SEs must be robust ("robust.huber.white"), because the weights make the model-based SEs wrong.
```

## Small-sample corrections to the robust standard errors

lavaan 0.7-3 adds `information_meat_hc`, a small-sample correction of
the casewise sandwich standard errors (the analogue of HC1, HC2 and HC3
for a regression), and `information_bread`, which picks the information
matrix used for the bread of the sandwich. Pass either through
`fit_args`. They change **standard errors only**; the point estimates
are unchanged. They apply when the standard errors are a sandwich: with
`method = "ipw"` (always) or with a robust estimator such as `"MLR"`.
With the default ML estimator they are accepted and ignored.

``` r

se_ab <- function(object) {
  tab <- tidy(pool(run(object)))
  tab[tab$term %in% c("a", "b"), c("term", "estimate", "std_error")]
}
mod_obs <- "Mobs ~ a * X + C\nY ~ b * Mobs + cp * X + C"
for (hc in c("none", "HC1", "HC3")) {
  fa <- list(estimator = "MLR")
  if (hc != "none") fa$information_meat_hc <- hc
  cat("MLR, information_meat_hc:", hc, "\n")
  print(se_ab(set_md_mediation(imp_obs,
    model = mod_obs, treatment = "X", mediator = "Mobs", outcome = "Y",
    engine = "lavaan", fit_args = fa
  )))
}
#> MLR, information_meat_hc: none 
#> # A tibble: 2 × 3
#>   term  estimate std_error
#>   <chr>    <dbl>     <dbl>
#> 1 a        0.563    0.102 
#> 2 b        0.518    0.0657
#> MLR, information_meat_hc: HC1 
#> # A tibble: 2 × 3
#>   term  estimate std_error
#>   <chr>    <dbl>     <dbl>
#> 1 a        0.563    0.104 
#> 2 b        0.518    0.0665
#> MLR, information_meat_hc: HC3 
#> # A tibble: 2 × 3
#>   term  estimate std_error
#>   <chr>    <dbl>     <dbl>
#> 1 a        0.563    0.103 
#> 2 b        0.518    0.0671
```

Under inverse probability weighting lavaan offers only `"HC1"` with
sampling weights; `"HC2"` and `"HC3"` are refused, and
[`run()`](https://data-wise.github.io/missingmed/reference/run.md)
reports lavaan’s message:

``` r

ipw_hc <- function(hc) {
  set_md_mediation(d,
    model = mod_obs, treatment = "X", mediator = "Mobs", outcome = "Y",
    engine = "lavaan", method = "ipw",
    fit_args = list(information_meat_hc = hc)
  )
}
se_ab(ipw_hc("HC1"))
#> # A tibble: 2 × 3
#>   term  estimate std_error
#>   <chr>    <dbl>     <dbl>
#> 1 a        0.658    0.124 
#> 2 b        0.416    0.0741
run(ipw_hc("HC3"))
#> Error:
#> ! engine "lavaan" failed on the IPW fit: lavaan->lav_hc_model_scores():  
#>    information_meat_hc = "HC3" is not available with sampling weights.
```

In these examples the corrections raise the standard errors by about 2%.
This tutorial does not calibrate them: the package’s Monte-Carlo and
MBCO checks were not run with these options.
`information_bread = "observed"` left the standard errors unchanged for
the models in this tutorial.

## Sensitivity analysis with a latent mediator

[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
shifts imputed values of a data column. A latent mediator has no column,
so name an observed indicator as `target`; the error lists the
indicators if you forget.

``` r

sensitivity_mnar(md_lat, delta = c(0, 0.5))
#> Error:
#> ! The mediator 'Mlat' is latent and has no data column, so `target` is required. Name one of its indicators: m1, m2, m3.
```

``` r

s <- sensitivity_mnar(md_lat,
  delta = c(-0.5, 0, 0.5), target = "m1",
  n.mc = 2000, seed = 1
)
tidy(s)
#> # A tibble: 3 × 7
#>      m1     msp estimate conf_low conf_high mechanism scale
#>   <dbl>   <dbl>    <dbl>    <dbl>     <dbl> <chr>     <chr>
#> 1  -0.5 -0.488     0.343    0.208     0.505 post      raw  
#> 2   0    0.0145    0.334    0.202     0.494 post      raw  
#> 3   0.5  0.517     0.326    0.194     0.485 post      raw
```

## The MBCO test with a lavaan fit

`infer(type = "mbco")` runs the same D4-stacked likelihood-ratio test of
H0: a·b = 0 as the glm engine, with lavaan doing the refits. Each
imputation is fit once in full and once with the `a` path (`Mlat ~ X`)
fixed to 0 and once with the `b` path (`Y ~ Mlat`) fixed to 0; the
stacked data are fit the same three ways. With a latent mediator, only
the **structural** path is fixed: the loadings, the measurement errors
and any direct effect of an indicator on `Y` stay free, so each branch
tests exactly one parameter (`k = 1`).

``` r

infer(fit_lat, type = "mbco")
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 5 imputations)
#>   D4 = 30.38 on F(1, Inf), p = 3.547e-08
#>   r4 = 0 (ariv = "fixed") | d_S = 30.38 
#>   stacked constrained fit: a = 0 branch
#>   imputations on the a = 0 branch: 100% (not mixed)
```

Read it as for the glm engine (see
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md)):
`D4` and `p` are the test, `r4` and `nu` describe the between-imputation
variability, and `branch_mix` reports whether the imputations disagreed
about which path is the weaker one. `r4 = 0` (so `F(1, Inf)`) is a
legitimate result: `r4` is clamped at 0 when the average per-imputation
statistic is not above the stacked one, which happens when the
imputations differ little for this statistic. Two properties to know:

- **It is conservative at a = b = 0.** The statistic is the smaller of
  two likelihood-ratio statistics, so when both paths are null the test
  rejects less often than its nominal level. That costs power near the
  intersection; it does not inflate false positives.
- **It does not test direct effects of the indicators.** Those are not
  part of `a * b`, so a nonzero direct effect of an indicator on `Y` is
  left in the model under both nulls.

The same test is available for a plain list of completed data frames,
without a
[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
object:

``` r

mbco_d4(mice::complete(imp, "all"),
  model = mod_lat, treatment = "X", mediator = "Mlat", outcome = "Y"
)
```

`sensitivity_mnar(type = "mbco")` works too, and returns one MBCO result
per rung.

### What it does not support

MBCO is refused, naming the option, for `estimator` other than `"ML"`
(`"MLR"`, `"MLM"`, `"WLSMV"`, …), for `group`, `ordered` and
`sampling.weights`, and for `method = "ipw"`. Robust (scaled) test
statistics are excluded because the D4 pooling is justified for
likelihood-ratio statistics, not for scaled ones, and no validated
pooling exists yet. Use `type = "mc"` for those fits.

A refit that does not converge stops the test, naming the imputation (or
the stacked data) and which fit; an improper solution warns once and
goes on.
