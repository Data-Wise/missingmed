# missingmed: Mediation Analysis with Multiple Imputation for Missing Data

missingmed runs SEM-based mediation analysis across multiply imputed
datasets and pools with Rubin's rules. It is a thin orchestration layer:
it **fits** each imputation with
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

## Deprecated S4 API

[`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md),
[`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md),
and
[`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)
are superseded by the S7 pipeline above and kept for one release cycle.

## See also

Useful links:

- <https://github.com/Data-Wise/missingmed>

- <https://data-wise.github.io/missingmed/>

- Report bugs at <https://github.com/Data-Wise/missingmed/issues>

## Author

Davood Tofighi <dtofighi@gmail.com>
