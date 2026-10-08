# Set up a mediation analysis with missing data (MI or IPW)

Constructs an
[MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
object: the entry point of the missingmed S7 pipeline. It records a
**medfit-style mediation specification** (outcome and mediator formulas
plus the treatment/mediator roles) together with the data. Fitting is
delegated to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html)
downstream by
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md).
It is the S7 successor of the S4
[`set_sem()`](https://data-wise.github.io/missingmed/dev/reference/set_sem.md)
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

  medfit fitting engine: `"glm"` (default), or `"regmedint"` (needs
  medfit \>= 0.4.0 and the regmedint package; `method = "mi"` only).

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
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
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

  Logical; if `TRUE`,
  [`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
  adds per-coefficient `conf_low` and `conf_high` columns to the pooled
  tidy table, at `conf_level` on Rubin's t reference. Defaults to
  `FALSE`. These bound single coefficients; for the indirect effect use
  [`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md).

- conf_level:

  Numeric in (0, 1); confidence level for `conf_int` and the default
  `level` of
  [`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md).
  Defaults to `0.95`.

## Value

An
[MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
object.

## Details

Two estimators share the interface (`method`):

- `"mi"` — `data` is a
  [mice::mids](https://amices.org/mice/reference/mids.html) object;
  [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
  fits every imputation.

- `"ipw"` — `data` is a raw `data.frame`;
  [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
  reweights the complete cases by inverse missingness probability and
  fits once.

The model is validated before anything is fit. Formulas are first
expanded against the data, so `Y ~ .` is checked as the model that
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
fits. `set_md_mediation()` refuses:

- a one-sided formula, or a `treatment`/`mediator` that is not a single
  variable name;

- a variable in either formula that is neither a column of the data nor
  defined in the formula's environment (the treatment and mediator must
  be columns);

- a `formula_m` whose response is not the bare `mediator` column (a
  transform such as `log(M)` needs its own column), or a `formula_y`
  whose response involves the mediator;

- a `treatment` that is not a main effect of `formula_m` and of
  `formula_y`, or a `mediator` that is not a main effect of `formula_y`;

- any other term involving the treatment or mediator. Both enter only as
  main effects, plus, in `formula_y` only, one treatment-by-mediator
  interaction (`X:M`, `M:X` or from `X * M`). Products such as `X:C`,
  `M:W` or `X:M:W`, transforms such as `I(X^2)`, `poly(X, 2)` or
  `log(M)`, and offsets involving either variable are refused. For
  moderated models,
  [`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md)
  tests the indirect effect on the completed datasets;

- an `X:M` term when `family_y` or `family_m` is not Gaussian with an
  identity link;

- a treatment column that is not numeric. Factor, character and logical
  treatments must be recoded to numeric (0/1 for a binary treatment);

- a `treatment` or `mediator` that is not a syntactic R name (such as
  `"my M"`), which medfit cannot fit. Covariates may have any name;

- an `engine` other than `"glm"`, or `"regmedint"` with medfit \>= 0.4.0
  and `method = "mi"` (regmedint takes no case weights);

- a `weight_formula` that is not `NULL`, a formula or a named list of
  formulas, or that uses a variable found neither in the data nor in its
  environment.

## See also

[MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md),
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md),
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html)

## Examples

``` r
set.seed(1)
d <- data.frame(X = rbinom(200, 1, .5), C = rnorm(200))
d$M <- .5 * d$X + .3 * d$C + rnorm(200)
d$Y <- .2 * d$X + .4 * d$M + .3 * d$C + rnorm(200)
d$M[sample(200, 30)] <- NA
# MI
imp <- mice::mice(d, m = 5, printFlag = FALSE, seed = 1)
md_mi <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M")
# IPW (raw data.frame)
md_ipw <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw")
```
