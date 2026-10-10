# Migrating from the S4 API

The S4 API was removed in missingmed 0.6.0. `set_sem()`, `run_sem()`,
`pool_sem()`, `fit_model()`, `lav_mice()` and `mx_mice()` were left as
stubs for one release that stopped with a message naming their
replacement; the stubs were deleted in 0.7.0, so calling them now gives
R’s “could not find function” error. This article maps the old calls to
the S7 pipeline.

## The mapping

| Removed | Replacement |
|----|----|
| `set_sem(data, model)` | `set_md_mediation(data, model = , treatment = , mediator = , outcome = , engine = "lavaan")` |
| `run_sem(object)` | `run(object)` |
| `pool_sem(object)` | `pool(object)` |
| `fit_model()`, `lav_mice()` | [`run()`](https://data-wise.github.io/missingmed/reference/run.md) fits every imputation |
| `mx_mice()`, OpenMx models | none: use `engine = "lavaan"` |
| `SemImputedData`, `SemResults`, `PooledSEMResults` | `MDMediationData`, `MDMediationFit`, `MDMediationResult` |
| `is_fit()`, `is_pd()`, `is_lav_syntax()`, `is_valid_lav_syntax()` | none (deleted without a stub; nothing in the S7 pipeline uses them) |
| [`tidy()`](https://generics.r-lib.org/reference/tidy.html) methods for OpenMx models and `logLik` objects | none (deleted) |
| (new) | `infer(fit, type = "mc")`; `type = "mbco"` for glm and lavaan (ML) models |

## From a lavaan model to `engine = "lavaan"`

The S4 call took a lavaan model string. The S7 call takes the same
string in `model`, and names the three roles. `outcome` is required: it
must be regressed on the mediator in `model`. Extra arguments for
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) go in
`fit_args`.

``` r

library(missingmed)
set.seed(4)
n <- 300
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 40)] <- NA
imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 4)

md <- set_md_mediation(imp,
  model = "M ~ a * X + C\nY ~ b * M + cp * X + C",
  treatment = "X", mediator = "M", outcome = "Y",
  engine = "lavaan"
)
res <- pool(run(md))
res@tidy_table[, c("term", "estimate", "std_error", "p_value")]
#>      term    estimate  std_error      p_value
#> 1       a  0.51046797 0.11055116 4.309150e-06
#> 2     M~C  0.32105479 0.05509479 6.091279e-09
#> 3       b  0.34247210 0.06019713 1.367182e-08
#> 4      cp -0.06635193 0.11626102 5.681995e-01
#> 5     Y~C  0.30234904 0.05931627 3.446507e-07
#> 6    M~~M  0.87871811 0.07462166           NA
#> 7    Y~~Y  0.93374164 0.07634275           NA
#> 8 c_prime -0.06635193 0.01179289 3.016672e-02
```

The p-values are normal-theory z-tests (`df` is `Inf` for a single
imputation, and Rubin’s large-sample df otherwise). Variance rows
(`M~~M`) keep their estimate and standard error, with `NA` for the
statistic and p-value, because their null (variance = 0) lies on the
boundary. A covariance between two different variables (`Y~~Y2`) keeps
its test.

A latent mediator uses the same call, with the latent variable as
`mediator`:

``` r

set_md_mediation(imp,
  model = "Mlat =~ m1 + m2 + m3\nMlat ~ a * X + C\nY ~ b * Mlat + cp * X + C",
  treatment = "X", mediator = "Mlat", outcome = "Y", engine = "lavaan"
)
```

## What changed for the formula path

The glm path is unchanged: `formula_y`, `formula_m`, `treatment`,
`mediator` as before. The path labels `a`, `b` and `c_prime` are fixed
in the pooled estimates. `res@tidy_table` is the pooled table.

## What lavaan fits cannot do yet

- **MBCO** works for lavaan fits with maximum likelihood
  (`infer(fit, type = "mbco")`, `mbco_d4(model = )`, and
  `sensitivity_mnar(type = "mbco")`). It is refused, naming the option,
  for `estimator` other than `"ML"` (`MLR`, `MLM`, `WLSMV`, …), `group`,
  `ordered` and `sampling.weights`. See the *Structural equation models*
  article.
- **IPW** works with `engine = "lavaan"`, with robust (sandwich)
  standard errors only.
- **[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)**
  works for `type = "mc"` and `type = "mbco"`. With a latent mediator,
  name an observed indicator in `target`.

## OpenMx

There is no OpenMx engine. Fit the model with lavaan, or fit it yourself
and pool outside missingmed.

## Pooled p-values since 0.5.1

p-values use Rubin’s t reference with Barnard–Rubin df since 0.5.1;
results from earlier versions can differ.
