# Changelog

## missingmed 0.2.0

Major release: the package is rewritten from S4 to **S7** and gains a
second estimator (IPW). It is now a thin orchestration layer — fitting
is delegated to [medfit](https://data-wise.github.io/medfit/) and
inference to [RMediation](https://data-wise.github.io/rmediation/).

### New S7 pipeline

Four verbs over three S7 classes:

    set_md_mediation()  ->  run()  ->  pool()  ->  infer()
       MDMediationData      MDMediationFit  MDMediationResult   CI / MBCO

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  — entry point; records the data + a medfit-style mediation spec
  (outcome/mediator formulas + treatment/mediator roles).
- [`run()`](https://data-wise.github.io/missingmed/reference/run.md) —
  fits each imputation via
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
  yielding a list of **named**
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html).
- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) —
  Rubin’s-rules pooling of the named (estimates, vcov) into a single
  **named** pooled
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html),
  valid input to
  [`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html).
- `infer(type = c("mc", "mbco"))` — Monte-Carlo /
  distribution-of-the-product CI (`mc`), or **D4-stacked MBCO**
  likelihood-ratio test (`mbco`).
- [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)
  — exposes the per-imputation fits for MBCO (which does **not** commute
  with Rubin’s rules).

New S7 classes: `MDMediationData`, `MDMediationFit`,
`MDMediationResult`.

### Estimators

- **Multiple imputation (`method = "mi"`)** — the default; pools `m`
  imputed-data fits with Rubin’s rules.
- **Inverse-probability weighting (`method = "ipw"`)** — new. Reweights
  the complete cases by inverse missingness probability and fits once.
  Supports a joint complete-case weight model (default) or per-variable
  formulas, stabilized weights, quantile trimming, and HC sandwich SEs
  (`se_type = "sandwich"`).

### MBCO under multiple imputation

- `infer(type = "mbco")` implements **D4-stacked MBCO**, which respects
  the union-null geometry of `H0: ab = 0` (branch switching) —
  exact-match parity with the research prototype. See
  [`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

### Documentation

- New vignettes: `missingmed` (getting started), `mbco-mi`, and
  `technical` (design, ecosystem contracts, and methodology).
- pkgdown site at <https://data-wise.github.io/missingmed/>.

### Deprecations

- The S4 API
  ([`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md),
  [`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md),
  [`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md),
  and the `SemImputedData` / `SemResults` / `PooledSEMResults` classes)
  is **deprecated** in favour of the S7 pipeline above. The shims emit a
  [`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) warning and
  will be removed in a future release.

### Dependencies

- New `Imports`: `S7`, `medfit` (\>= 0.3.1), `RMediation` (\>= 1.4.0).
  `medfit` and `RMediation` are available from the Data-Wise R-universe.

## missingmed 0.1.0

- Initial S4 implementation: SEM-based mediation across multiply imputed
  datasets (`mice` + `lavaan`/`OpenMx`) with Rubin’s-rules pooling.
