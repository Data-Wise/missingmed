# Migrating from the S4 API

The S4 functions
[`set_sem()`](https://data-wise.github.io/missingmed/dev/reference/set_sem.md),
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md)
and
[`pool_sem()`](https://data-wise.github.io/missingmed/dev/reference/pool_sem.md)
and their classes are deprecated. They still run, with a deprecation
warning, and they are planned to become
[`.Defunct()`](https://rdrr.io/r/base/Defunct.html) stubs in 0.6.0, each
naming its replacement. This article maps the old calls to the S7
pipeline.

## The mapping

| S4 (deprecated) | S7 | Returns |
|----|----|----|
| `set_sem(data, model)` | `set_md_mediation(data, formula_y, formula_m, treatment, mediator)` | `MDMediationData` |
| `run_sem(object)` | `run(object)` | `MDMediationFit` |
| `pool_sem(object)` | `pool(object)` | `MDMediationResult` |
| (none) | `infer(fit, type = "mc" or "mbco")` | interval or test for the indirect effect |
| `SemImputedData`, `SemResults`, `PooledSEMResults` | `MDMediationData`, `MDMediationFit`, `MDMediationResult` |  |

## From model syntax to two formulas

The S4 API took a lavaan model string or an OpenMx model. The S7 API
takes the mediator model and the outcome model as two formulas, plus the
names of the treatment and the mediator. An observed-variable lavaan
model

``` r

model <- "
  M ~ a * X + C
  Y ~ b * M + cp * X + C
"
res_s4 <- pool_sem(run_sem(set_sem(imp, model)))
```

becomes

``` r

library(missingmed)
set.seed(4)
n <- 300
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 40)] <- NA
imp <- mice::mice(d, m = 5, method = "norm", printFlag = FALSE, seed = 4)

md <- set_md_mediation(imp,
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  treatment = "X", mediator = "M"
)
fit <- run(md)
res <- pool(fit)
res
#> <MDMediationResult> (pooled, Rubin's rules; m = 5 )
#>     term   estimate  std_error
#>        a  0.5272309 0.11583499
#>        b  0.3428317 0.06713217
#>  c_prime -0.0723091 0.11888413
#>   indirect effect a*b = 0.1808 
#>   -> infer(type = "mc") for the indirect-effect CI
```

The path labels are fixed rather than user-chosen: `a`, `b` and
`c_prime` in the pooled estimates, plus `theta3` and `b0` for an `X:M`
model. The pooled table is `res@tidy_table`.

## What the S7 pipeline adds

- [`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md):
  a Monte Carlo interval for the indirect effect, or the D4-MBCO test,
  where the S4 API pooled path coefficients only.
- `method = "ipw"` for inverse probability weighting.
- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
  for departures from MAR.
- Validation of the model before fitting (see the *Supported models*
  article).

## What has no replacement yet

- **Latent mediators and other SEM features.** A lavaan engine for
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md)
  is planned for 0.6.0.
- **OpenMx models.** No OpenMx engine is planned for 0.6.0.

Until then, these models still run through the deprecated S4 functions.

## Silencing the warning while you migrate

The deprecation warning is an ordinary warning, so a script that must
keep the S4 call for now can wrap it in
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html). Note that
[`pool_sem()`](https://data-wise.github.io/missingmed/dev/reference/pool_sem.md)
p-values use Rubin’s t reference with Barnard–Rubin df since 0.5.1;
results from earlier versions can differ.
