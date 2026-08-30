# Set up a mediation analysis with missing data (MI or IPW)

Constructs an
[MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
object: the entry point of the missingmed S7 pipeline. It records a
**medfit-style mediation specification** (outcome and mediator formulas
plus the treatment/mediator roles) together with the data. Fitting is
delegated to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html)
downstream by
[`run()`](https://data-wise.github.io/missingmed/reference/run.md). It
is the S7 successor of the S4
[`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md)
constructor.

## Usage

``` r
set_md_mediation(
  data,
  formula_y,
  formula_m,
  treatment,
  mediator,
  engine = "glm",
  family_y = stats::gaussian(),
  family_m = stats::gaussian(),
  method = c("mi", "ipw"),
  mechanism = c("mar", "mnar"),
  weight_formula = NULL,
  weight_stabilize = TRUE,
  weight_trim = 1,
  se_type = c("sandwich", "model"),
  conf_int = FALSE,
  conf_level = 0.95
)
```

## Arguments

- data:

  For `method = "mi"`, a
  [mice::mids](https://amices.org/mice/reference/mids.html) object; for
  `method = "ipw"`, a `data.frame` (may contain `NA`s; complete cases
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

  medfit fitting engine. Defaults to `"glm"`.

- family_y, family_m:

  [`stats::family`](https://rdrr.io/r/stats/family.html) objects for the
  outcome and mediator models. Default
  [`stats::gaussian()`](https://rdrr.io/r/stats/family.html).

- method:

  Estimator axis: `"mi"` (default) or `"ipw"`.

- mechanism:

  **Deprecated.** The pipeline estimates under MAR regardless, so this
  argument never changed behavior. Passing `"mnar"` warns and is
  ignored. Use
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  to assess departures from MAR; it sets `mechanism = "mnar"` on the
  objects it creates.

- weight_formula:

  (IPW) Missingness model: `NULL` (default; all observed predictors), a
  single `formula`, or a named `list` of per-variable formulas.

- weight_stabilize:

  (IPW) Use stabilized weights? Default `TRUE`.

- weight_trim:

  (IPW) Upper quantile to cap weights; `1` (default) = none.

- se_type:

  (IPW) `"sandwich"` (default, HC robust) or `"model"`.

- conf_int:

  Logical; whether downstream output carries confidence intervals.
  Defaults to `FALSE`.

- conf_level:

  Numeric in (0, 1); confidence level. Defaults to `0.95`.

## Value

An
[MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
object.

## Details

Two estimators share the interface (`method`):

- `"mi"` — `data` is a
  [mice::mids](https://amices.org/mice/reference/mids.html) object;
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  fits every imputation.

- `"ipw"` — `data` is a raw `data.frame`;
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  reweights the complete cases by inverse missingness probability and
  fits once.

## See also

[MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md),
[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html)

## Examples

``` r
if (FALSE) { # \dontrun{
set.seed(1)
d <- data.frame(X = rbinom(200, 1, .5), C = rnorm(200))
d$M <- .5 * d$X + .3 * d$C + rnorm(200)
d$Y <- .2 * d$X + .4 * d$M + .3 * d$C + rnorm(200)
d$M[sample(200, 30)] <- NA
# MI
imp <- mice::mice(d, m = 5, printFlag = FALSE)
md_mi <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M")
# IPW (raw data.frame)
md_ipw <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw")
} # }
```
