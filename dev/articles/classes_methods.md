# S7 classes and methods

A developer’s map of missingmed’s object model: which S7 class each verb
takes and returns, what each class carries, and which generics dispatch
on it. For the statistics behind the verbs, see
[`vignette("technical")`](https://data-wise.github.io/missingmed/dev/articles/technical.md).

## The pipeline

Four verbs move a mediation analysis through three classes. Inference
returns either an `RMediation` interval or a fourth class, and the
sensitivity analysis returns a fifth.

``` mermaid
flowchart LR
  D["MDMediationData"] -->|"run()"| F["MDMediationFit"]
  F -->|"pool()"| R["MDMediationResult"]
  R -->|"infer(type = 'mc')"| CI["RMediation interval (list)"]
  F -->|"infer(type = 'mc')"| CI
  F -->|"infer(type = 'mbco')"| M["MbcoMIResult"]
  D -->|"sensitivity_mnar()"| S["MDSensitivityResult"]
  S -. "one infer() result per rung" .-> CI
  S -.-> M
```

`infer(type = "mbco")` takes the **fit**, not the pooled result: the
MBCO statistic does not commute with Rubin’s rules, so it needs every
imputation. `infer(<MDMediationResult>, type = "mbco")` is an error by
design.

## Classes

Each class below is an
[`S7::new_class()`](https://rconsortium.github.io/S7/reference/new_class.html)
with `package = "missingmed"`. The property lists are read from the
class objects when this page is built.

| class | parent | properties |
|:---|:---|:---|
| MDMediationData | S7_object | `data`, `formula_y`, `formula_m`, `treatment`, `mediator`, `engine`, `family_y`, `family_m`, `method`, `mechanism`, `weight_formula`, `weight_stabilize`, `weight_trim`, `se_type`, `conf_int`, `conf_level`, `n_imputations`, `model`, `outcome`, `fit_args`, `original_data` |
| MDMediationFit | S7_object | `per_imputation`, `fits`, `m`, `engine`, `conf_int`, `conf_level`, `weights`, `source` |
| MDMediationResult | S7_object | `pooled`, `tidy_table`, `cov_total`, `cov_between`, `cov_within`, `m`, `engine`, `conf_int`, `conf_level` |
| MbcoMIResult | class_double | `ariv`, `k`, `m`, `stacked_branch`, `branch_mix`, `p_branch_a` |
| MDSensitivityResult | S7_object | `rungs`, `grid`, `msp`, `target`, `type`, `level`, `seed`, `seed_source`, `method_target`, `mechanism_used`, `scale`, `source` |

- **`MDMediationData`**, built by
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
  holds the analysis specification: the data (a
  [`mice::mids`](https://amices.org/mice/reference/mids.html) for
  `method = "mi"`, a data frame for `method = "ipw"`), the two model
  formulas and families, the treatment and mediator names, and the IPW
  weight settings.
- **`MDMediationFit`**, returned by
  [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
  holds one named
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html)
  per imputation in `per_imputation`, plus the raw fits and, for IPW,
  the weights. `source` points back to the `MDMediationData`, which is
  how `infer(type = "mbco")` reaches the imputed datasets.
- **`MDMediationResult`**, returned by
  [`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md),
  holds the Rubin’s-rules pooled
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html)
  in `pooled`, its tidy table with per-coefficient Wald tests, and the
  within, between and total covariance matrices.
- **`MbcoMIResult`**, returned by `infer(type = "mbco")` and
  [`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md),
  is the only class with a base-type parent (`class_double`). Its data
  is the named vector `c(D4, p, r4, nu, d_S)`; its properties record
  `ariv`, the numerator df `k`, the number of imputations `m`, and the
  branch diagnostics.
- **`MDSensitivityResult`**, returned by
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md),
  holds one inference result per `delta` rung in `rungs`, the `grid` of
  deltas, and the realized marginal sensitivity parameter `msp` for each
  rung.

## Generics and methods

| generic | methods for |
|:---|:---|
| run | `MDMediationData` |
| pool | `ANY`, `MDMediationData`, `MDMediationFit`, `MDMediationResult` |
| infer | `MDMediationFit`, `MDMediationResult` |
| per_imputation_list | `MDMediationFit` |
| n_imputations | `MDMediationFit`, `MDMediationResult` |

The methods on the wrong class are refusals with a pointer to the right
step: `pool(<MDMediationData>)` asks for
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
first, and `pool(<MDMediationResult>)` says the object is already
pooled.
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
on any other object falls through to
[`mice::pool()`](https://amices.org/mice/reference/pool.html).

Output methods are S7 methods on external generics:

| Generic | Classes |
|----|----|
| [`print()`](https://rdrr.io/r/base/print.html) | all five |
| [`summary()`](https://rdrr.io/r/base/summary.html) | `MDMediationResult`, `MDSensitivityResult` |
| [`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) (re-exported) | `MDMediationResult`, `MbcoMIResult`, `MDSensitivityResult` |
| `[`, `[[` | `MbcoMIResult` (index the underlying vector) |

## Working with an `MbcoMIResult`

S7 objects are not subsettable by default, so `MbcoMIResult` defines `[`
and `[[` on its data. Properties use `@`; `$` is an error.

``` r

set.seed(1)
implist <- lapply(1:3, function(i) {
  X <- rnorm(200)
  M <- 0.4 * X + rnorm(200)
  data.frame(X = X, M = M, Y = 0.3 * M + rnorm(200))
})
r <- mbco_d4(implist, Y ~ X + M, M ~ X,
  treatment = "X", mediator = "M", ariv = "fixed"
)
r[["p"]]
#> [1] 0.0009082534
r[c("D4", "nu")]
#>        D4        nu 
#>  11.13565 513.14364
r@stacked_branch
#> [1] "b"
is.numeric(r)
#> [1] TRUE
S7::S7_data(r)
#>           D4            p           r4           nu          d_S 
#> 1.113565e+01 9.082534e-04 6.658739e-02 5.131436e+02 1.187715e+01
```

## Registration notes for contributors

- `R/zzz.R` calls
  [`S7::methods_register()`](https://rconsortium.github.io/S7/reference/methods_register.html)
  in `.onLoad()`, which registers the S7 methods on external generics at
  load time, so they need no `S3method()` lines in `NAMESPACE`.
- `MDMediationData`, `MDMediationFit`, `MDMediationResult` and
  `MDSensitivityResult` are passed to
  [`S7::S4_register()`](https://rconsortium.github.io/S7/reference/S4_register.html),
  so S4 code can dispatch on them.
- `MbcoMIResult` is **not**:
  [`setOldClass()`](https://rdrr.io/r/methods/setOldClass.html) cannot
  build an S4 prototype for an S7 class whose parent is `class_double`.
  Two consequences:
  - Inside the namespace, `print` is an S4 generic (`import(OpenMx)`
    makes it one), and S7 refuses to add a method for an unregistered
    class to an S4 generic. Its print method is therefore registered on
    [`base::print`](https://rdrr.io/r/base/print.html).
  - Register methods for it with the functional form,
    `` S7::`method<-`(generic, MbcoMIResult, value = f) ``. The
    assignment form `S7::method(generic, MbcoMIResult) <- f` assigns the
    generic back into the namespace; for `[` and `[[` that creates
    objects `R CMD check` reports as undocumented.
- Every exported class and function needs an entry in the `reference:`
  index of `_pkgdown.yml`; `R CMD check` does not read it, but the
  pkgdown CI job fails without it.

## Deprecated S4 classes

The S4 API
([`set_sem()`](https://data-wise.github.io/missingmed/dev/reference/set_sem.md),
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md),
[`pool_sem()`](https://data-wise.github.io/missingmed/dev/reference/pool_sem.md)
with the classes `SemImputedData`, `SemResults` and `PooledSEMResults`)
is deprecated behind
[`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) shims and
becomes [`.Defunct()`](https://rdrr.io/r/base/Defunct.html) stubs in
0.6.0. Each S7 class above replaces one of them:

| S7 class            | Replaces           |
|---------------------|--------------------|
| `MDMediationData`   | `SemImputedData`   |
| `MDMediationFit`    | `SemResults`       |
| `MDMediationResult` | `PooledSEMResults` |
