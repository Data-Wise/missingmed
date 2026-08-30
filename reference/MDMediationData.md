# MDMediationData: imputed data + mediation specification (S7)

An S7 class holding multiply imputed data together with a **medfit-style
mediation specification** (outcome/mediator formulas + roles). It is the
entry point of the missingmed S7 pipeline
([`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
-\> [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
-\> [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
-\>
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md))
and the S7 successor of the S4
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
class.

## Usage

``` r
MDMediationData(
  data = NULL,
  formula_y = NULL,
  formula_m = NULL,
  treatment = character(0),
  mediator = character(0),
  engine = "glm",
  family_y = NULL,
  family_m = NULL,
  method = "mi",
  mechanism = "mar",
  weight_formula = NULL,
  weight_stabilize = TRUE,
  weight_trim = 1,
  se_type = "sandwich",
  conf_int = FALSE,
  conf_level = 0.95,
  n_imputations = integer(0),
  original_data = data.frame()
)
```

## Arguments

- data:

  For `method = "mi"`, an object of class `mids` from the `mice`
  package; for `method = "ipw"`, a raw `data.frame` (the complete cases
  are reweighted).

- formula_y:

  Outcome model formula (e.g. `Y ~ X + M + C`).

- formula_m:

  Mediator model formula (e.g. `M ~ X + C`).

- treatment:

  Name of the treatment/exposure variable.

- mediator:

  Name of the mediator variable.

- engine:

  medfit fitting engine, e.g. `"glm"` (default).

- family_y, family_m:

  [`stats::family`](https://rdrr.io/r/stats/family.html) objects for the
  outcome and mediator models. Default
  [`stats::gaussian()`](https://rdrr.io/r/stats/family.html).

- method:

  Estimator axis: `"mi"` (default) or `"ipw"`.

- mechanism:

  Assumed missing-data mechanism: `"mar"` (default) or `"mnar"`.

- weight_formula:

  (IPW) Missingness model specification: `NULL` (default; use all
  observed predictors), a single `formula` (joint complete-case model),
  or a named `list` of formulas (per-variable models). Ignored for MI.

- weight_stabilize:

  (IPW) Logical; if `TRUE` (default) use stabilized weights
  `P(R=1|X) / P(R=1|Z)`. Ignored for MI.

- weight_trim:

  (IPW) Upper quantile at which to cap weights (e.g. `0.99`); `1`
  (default) disables trimming. Ignored for MI.

- se_type:

  (IPW) Variance estimator passed to
  [`medfit::fit_mediation()`](https://rdrr.io/pkg/medfit/man/fit_mediation.html):
  `"sandwich"` (default for IPW, HC robust) or `"model"`. Ignored for
  MI.

- conf_int:

  Logical; whether downstream output carries confidence intervals.
  Defaults to `FALSE`.

- conf_level:

  Numeric in (0, 1); confidence level. Defaults to `0.95`.

- n_imputations:

  Number of imputations (MI) or `1` (IPW).

- original_data:

  The original data (pre-imputation for MI; the supplied frame for IPW).

## Value

An `MDMediationData` S7 object.

## Details

Fitting is delegated to
[`medfit::fit_mediation()`](https://rdrr.io/pkg/medfit/man/fit_mediation.html)
(one call per imputation), so the per-imputation fits carry **named**
path coefficients (`a`, `b`, `c_prime`) ready for
[RMediation](https://data-wise.github.io/rmediation/reference/RMediation-package.html)
inference. The estimator (`method`) and the model are orthogonal axes:
`method` selects the missing-data estimator (`"mi"`/`"ipw"`); the
formulas/engine select the model.

## See also

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md),
[`medfit::fit_mediation()`](https://rdrr.io/pkg/medfit/man/fit_mediation.html),
[SemImputedData](https://data-wise.github.io/missingmed/reference/SemImputedData.md)
