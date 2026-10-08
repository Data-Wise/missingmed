# Inference on the indirect effect under multiple imputation

Computes inference for the indirect (mediated) effect from a fitted
missingmed pipeline, dispatching to one of two engines:

## Usage

``` r
infer(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
  (supports both `"mc"` and `"mbco"`) or an
  [MDMediationResult](https://data-wise.github.io/missingmed/reference/MDMediationResult.md)
  (supports `"mc"`).

- ...:

  Method arguments: `type` (inference type, `"mc"` (default) or
  `"mbco"`), `level` (confidence level for `"mc"`; defaults to the
  object's `@conf_level`, itself `0.95` unless set in
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)),
  `n.mc` (Monte-Carlo draws for `"mc"`, default `1e5`), and `ariv` (for
  `"mbco"`: `"fixed"` (default) tests every imputation on the branch the
  stacked constrained fit chose; `"own"` uses each imputation's own
  winning branch and reproduces missingmed 0.4.0 on full-rank designs;
  see
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)),
  and `treatment_level` (for `"mc"` on a model with an `X:M` term, and
  only there: the treatment level \\x\\ at which the indirect effect \\a
  (b + \theta_3 x)\\ is evaluated, that is, the effect of a one-unit
  increase in X through M with X held at \\x\\ in the outcome model. For
  a 0/1 treatment, `1` gives the total natural indirect effect and `0`
  the pure natural indirect effect. Required for such models; an error
  otherwise). Any other argument is an error, so a misspelled one (say
  `conf.level`) is not silently dropped.

## Value

For `"mc"`, the list returned by
[`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
(`CI`, `Estimate`, `SE`, `MC.Error`); for a model with an `X:M` term,
the same elements plus `Estimand`, the formula the interval is for. For
`"mbco"`, an
[MbcoMIResult](https://data-wise.github.io/missingmed/reference/MbcoMIResult.md):
the named numeric `c(D4, p, r4, nu, d_S)` (index it with `r["p"]` or
`r[["p"]]`) with the branch diagnostics as properties.

## Details

- `type = "mc"` — Monte-Carlo / distribution-of-the-product confidence
  interval via
  [`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
  applied to the **pooled** named
  [medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html).
  When the outcome model has a treatment-by-mediator interaction
  (`Y ~ X * M + ...`), the indirect effect is \\a (b + \theta_3 x)\\,
  which depends on the treatment level \\x\\; set `treatment_level` to
  choose it. The interval then comes from
  [`RMediation::ci()`](https://data-wise.github.io/rmediation/reference/ci.html)
  on the pooled estimates and pooled covariance of \\(a, b, \theta_3)\\.

- `type = "mbco"` — **D4-stacked MBCO** likelihood-ratio test of \\H_0:
  a b = 0\\, computed from the per-imputation datasets (MBCO does not
  commute with Rubin's rules; see
  [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)).
  The engine is
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md);
  see there for `ariv`, the branch diagnostics and the cost. At least
  two imputations are required.

## See also

[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md),
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md),
[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)

## Examples

``` r
set.seed(1)
n <- 200
d <- data.frame(X = rnorm(n), C = rnorm(n))
d$M <- 0.4 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 30)] <- NA
d$Y[sample(n, 30)] <- NA
imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
))
r <- infer(fit, type = "mbco", ariv = "fixed")
r
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 3 imputations)
#>   D4 = 17.65 on F(1, 723.4), p = 2.985e-05
#>   r4 = 0.0555 (ariv = "fixed") | d_S = 18.63 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 0% (not mixed)
r[["p"]]
#> [1] 2.985434e-05
```
