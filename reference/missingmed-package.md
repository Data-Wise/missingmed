# missingmed: Mediation Analysis with Multiple Imputation for Missing Data

missingmed runs regression-based mediation analysis across multiply
imputed datasets and pools with Rubin's rules. It is a thin
orchestration layer: it **fits** each imputation with
[medfit](https://data-wise.github.io/medfit/reference/medfit-package.html)
and delegates **inference** to
[RMediation](https://data-wise.github.io/rmediation/reference/RMediation-package.html).

## S7 pipeline

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  -\>
  [MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md):
  imputed data + mediation spec

- [`run()`](https://data-wise.github.io/missingmed/reference/run.md) -\>
  [MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md):
  a list of named
  [medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html),
  one per imputation

- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  -\>
  [MDMediationResult](https://data-wise.github.io/missingmed/reference/MDMediationResult.md):
  Rubin's-rules pooled named
  [medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)

- [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md):
  indirect-effect CI
  ([`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html))
  or D4-stacked MBCO

- [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md):
  per-imputation fits for MBCO (which does not commute with Rubin's
  rules)

## Removed S4 API

The S4 functions `set_sem()`, `run_sem()`, `pool_sem()`, `fit_model()`,
`lav_mice()` and `mx_mice()` were deprecated in 0.5.0, turned into
[`.Defunct()`](https://rdrr.io/r/base/Defunct.html) stubs in 0.6.0 and
removed in 0.7.0. See `vignette("s4-migration", package = "missingmed")`
for the replacements.

## Lifecycle

Stages follow the [tidyverse
lifecycle](https://lifecycle.r-lib.org/articles/stages.html). Features
not listed here carry no stage badge.

- **\[experimental\]** `sensitivity_mnar(on_error =)` (since 0.9.0).

- **\[deprecated\]** extra arguments in `run(...)` and
  `sensitivity_mnar(...)` (since 0.7.0): use `fit_args` in
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md).

- **\[deprecated\]** `set_md_mediation(mechanism = "mnar")` (since
  0.3.0): it has no effect.

Deprecations warn through the lifecycle package: once per session (every
eight hours) by default; set `options(lifecycle_verbosity = "warning")`
to see every one. The S4 functions listed above are removed, not
deprecated.

## See also

Useful links:

- <https://github.com/Data-Wise/missingmed>

- <https://data-wise.github.io/missingmed/>

- Report bugs at <https://github.com/Data-Wise/missingmed/issues>

## Author

Davood Tofighi <dtofighi@gmail.com>
