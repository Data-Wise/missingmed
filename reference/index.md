# Package index

## Pipeline

The S7 mediation-with-missing-data workflow.

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  : Set up a mediation analysis with missing data (MI or IPW)
- [`run()`](https://data-wise.github.io/missingmed/reference/run.md) :
  Fit the mediation model across imputations
- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) :
  Pool per-imputation mediation fits with Rubin's rules
- [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
  : Inference on the indirect effect under multiple imputation

## Sensitivity analysis

Departures from MAR. Produces a sensitivity curve, not an estimate –
nothing here is identified.

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  : MNAR sensitivity analysis by delta-adjusted imputation

## Accessors

- [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)
  : Access the per-imputation mediation fits (for MBCO)
- [`n_imputations()`](https://data-wise.github.io/missingmed/reference/n_imputations.md)
  : Number of imputations

## Classes

The S7 classes carrying data, fits, pooled results, and sensitivity
curves.

- [`MDMediationData()`](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
  : MDMediationData: imputed data + mediation specification (S7)
- [`MDMediationFit()`](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
  : MDMediationFit: per-imputation mediation fits (S7)
- [`MDMediationResult()`](https://data-wise.github.io/missingmed/reference/MDMediationResult.md)
  : MDMediationResult: pooled mediation result (S7)
- [`MDSensitivityResult()`](https://data-wise.github.io/missingmed/reference/MDSensitivityResult.md)
  : MDSensitivityResult: MNAR sensitivity curve (S7)

## Tidiers

- [`tidy(`*`<logLik>`*`)`](https://data-wise.github.io/missingmed/reference/tidy_logLik.md)
  : Creates a data.frame for a log-likelihood object
- [`tidy(`*`<MxModel>`*`)`](https://data-wise.github.io/missingmed/reference/tidy_MxModel.md)
  : Tidy an MxModel Object

## Low-level helpers

Fitting and validation utilities used by the pipeline.

- [`fit_model()`](https://data-wise.github.io/missingmed/reference/fit_model.md)
  : Fit a Structural Equation Model
- [`lav_mice()`](https://data-wise.github.io/missingmed/reference/lav_mice.md)
  : Fit SEM Model to Each Dataset in a MIDS Object Without Pooling
- [`mx_mice()`](https://data-wise.github.io/missingmed/reference/mx_mice.md)
  : Fit OpenMx model to multiply imputed datasets
- [`n_imp()`](https://data-wise.github.io/missingmed/reference/n_imp.md)
  : Get Number of Imputations from a mids Object
- [`is_fit()`](https://data-wise.github.io/missingmed/reference/is_fit.md)
  : Determine If a SEM Model Has Been Fitted
- [`is_pd()`](https://data-wise.github.io/missingmed/reference/is_pd.md)
  : Checks if a matrix object is positive definite
- [`is_lav_syntax()`](https://data-wise.github.io/missingmed/reference/is_lav_syntax.md)
  : Function to check if lavaan model syntax is valid
- [`is_valid_lav_syntax()`](https://data-wise.github.io/missingmed/reference/is_valid_lav_syntax.md)
  : Function to check if lavaan model syntax is valid

## Deprecated (S4)

Superseded by the S7 pipeline; kept for one release cycle.

- [`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md)
  : Set up an SEM model with multiply imputed data.
- [`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md)
  : Run a SEM model
- [`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)
  : Pool SEM Analysis Results
- [`SemImputedData`](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
  [`SemImputedData-class`](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
  : SemImputedData Class
- [`SemResults`](https://data-wise.github.io/missingmed/reference/SemResults.md)
  [`SemResults-class`](https://data-wise.github.io/missingmed/reference/SemResults.md)
  : SemResults Class
- [`PooledSEMResults`](https://data-wise.github.io/missingmed/reference/PooledSEMResults-class.md)
  [`PooledSEMResults-class`](https://data-wise.github.io/missingmed/reference/PooledSEMResults-class.md)
  : Pooled SEM Analysis Results Class
- [`show(`*`<SemImputedData>`*`)`](https://data-wise.github.io/missingmed/reference/show-SemImputedData-method.md)
  : Show SemImputedData
- [`summary(`*`<SemImputedData>`*`)`](https://data-wise.github.io/missingmed/reference/summary-SemImputedData-method.md)
  : Summary Method for SemImputedData Objects
