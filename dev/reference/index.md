# Package index

## Pipeline

The S7 mediation-with-missing-data workflow.

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md)
  : Set up a mediation analysis with missing data (MI or IPW)
- [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
  : Fit the mediation model across imputations
- [`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
  : Pool per-imputation mediation fits with Rubin's rules
- [`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)
  : Inference on the indirect effect under multiple imputation
- [`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md)
  : D4-stacked MBCO test of an indirect effect across imputed datasets

## Sensitivity analysis

Departures from MAR. Produces a sensitivity curve, not an estimate –
nothing here is identified.

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
  : MNAR sensitivity analysis by delta-adjusted imputation

## Accessors

- [`per_imputation_list()`](https://data-wise.github.io/missingmed/dev/reference/per_imputation_list.md)
  : Access the per-imputation mediation fits (for MBCO)
- [`n_imputations()`](https://data-wise.github.io/missingmed/dev/reference/n_imputations.md)
  : Number of imputations

## Classes

The S7 classes carrying data, fits, pooled results, and sensitivity
curves.

- [`MDMediationData()`](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
  : MDMediationData: imputed data + mediation specification (S7)
- [`MDMediationFit()`](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
  : MDMediationFit: per-imputation mediation fits (S7)
- [`MDMediationResult()`](https://data-wise.github.io/missingmed/dev/reference/MDMediationResult.md)
  : MDMediationResult: pooled mediation result (S7)
- [`MDSensitivityResult()`](https://data-wise.github.io/missingmed/dev/reference/MDSensitivityResult.md)
  : MDSensitivityResult: MNAR sensitivity curve (S7)
- [`MbcoMIResult()`](https://data-wise.github.io/missingmed/dev/reference/MbcoMIResult.md)
  : MbcoMIResult: D4-stacked MBCO test result (S7)

## Low-level helpers

Fitting and validation utilities used by the pipeline.

- [`n_imp()`](https://data-wise.github.io/missingmed/dev/reference/n_imp.md)
  : Get the number of imputations from a mids object
