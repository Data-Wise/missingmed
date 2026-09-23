# MNAR sensitivity analysis by delta-adjusted imputation

Re-imputes the data across a grid of delta values and re-runs the
mediation pipeline at each rung, producing a **sensitivity curve** for
the indirect effect. It is not an estimator: MAR versus MNAR is not
testable from observed data, so nothing here is identified. A rung
answers "if the unobserved values of `target` sit delta units away from
what MAR imputation implies, the indirect effect is X".

## Usage

``` r
sensitivity_mnar(
  object,
  delta,
  target = NULL,
  type = c("mc", "mbco"),
  seed = NULL,
  level = NULL,
  n.mc = 1e+05,
  ums = NULL,
  ...
)
```

## Arguments

- object:

  An
  [MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
  with `method = "mi"`.

- delta:

  Numeric vector (one rung per value, applied to `target`), or a data
  frame (one rung per row, one column per target variable). Supply
  either `delta` or `ums`, not both.

- target:

  Name of the variable to shift. Defaults to the mediator. Must be
  `NULL` when `delta` is a data frame.

- type:

  Inference per rung: `"mc"` (default) or `"mbco"`.

- seed:

  Integer seed pinned across rungs. Defaults to the seed stored in the
  `mids` object, or `20260822L` when that is `NA`.

- level, n.mc:

  Passed to
  [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md).

- ums:

  Optional character vector for a **covariate-varying** delta, one rung
  per string, passed verbatim to `mice`'s NARFCS `ums` (e.g.
  `"1 + 0.5*C"`: the offset is 1 + 0.5 C per row). Each string needs
  exactly one intercept term. Only for a single target routed to
  `mnar.norm` or `mnar.logreg`. A `ums` grid has no numeric ordering, so
  [`summary()`](https://rdrr.io/r/base/summary.html) does not compute a
  tipping point for it.

- ...:

  Passed to
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md).

## Value

An
[MDSensitivityResult](https://data-wise.github.io/missingmed/reference/MDSensitivityResult.md).

## Method

Delta-adjusted imputation in the pattern-mixture sense (van Buuren,
*FIMD* §9.2; Leacy et al. 2017). For a continuous target the canonical
procedure imputes under MAR and then adds the constant to the imputed
values (Hayati Rezvan et al. 2018). How the delta enters depends on the
target's imputation method:

- `"norm"` with a `ums` string: delegated to `mice`'s NARFCS method
  `mnar.norm` (Tompsett et al. 2018; Moreno-Betancur, van Buuren & White
  2020), delta in raw units. A numeric `delta` on a `norm` target uses
  the `post` shift below – for a constant delta the two give identical
  draws.

- `"logreg"` (a binary target): delegated to `mnar.logreg`, which
  offsets the imputation model's linear predictor – delta on the
  **log-odds** scale.

- anything else continuous (`pmm`, `norm.nob`, `cart`, ...), and `norm`
  with a numeric `delta`: the drawn values are shifted through `mice`'s
  `post` argument, delta in raw units.

Each rung re-imputes from the `mids` object's stored settings – never
from its recorded `call`, which does not resolve outside the function
that built it.

## The delta scale (read this before choosing a value)

`delta` is a **conditional** sensitivity parameter (CSP): a difference
conditional on all remaining variables and their missingness indicators.
The quantity an analyst can actually reason about – "non-respondents
average delta units higher" – is a **marginal** sensitivity parameter
(MSP), and the two are different numbers. Supplying an elicited MSP as
if it were a CSP is the standard failure mode of this method and can
badly damage coverage (Tompsett et al. 2018). This function therefore
reports the **realized MSP** at every rung; compare it against what you
meant.

## Limitations

- Only `method = "mi"`. IPW has no imputations to shift.

- A numeric 0/1 target whose imputations are themselves 0/1 (`pmm`,
  `cart`, `sample`, ...) is refused unless it is imputed by `logreg`: an
  added delta would turn its values into 1s and 2s. A normal-model
  (`norm*`) imputation of a 0/1 variable is continuous and is allowed;
  its delta is on the raw (probability) scale, so keep it small and
  check the realized `msp`.

- Categorical targets: binary via `logreg` only. Multinomial and ordinal
  targets (`polyreg`, `polr`, `lda`) are refused – `mice` has no NARFCS
  method for them – and so is `logreg.boot`, which has no counterpart.

- With `pmm` (mice's default), shifted values may fall outside the
  observed range that `pmm` otherwise guarantees. A message is emitted
  once.

- The curve assumes the supplied imputation model is compatible with the
  mediation model; missingmed cannot verify this.

## See also

[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[MDSensitivityResult](https://data-wise.github.io/missingmed/reference/MDSensitivityResult.md)
