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
  frame (one rung per row, one column per target variable).

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
values (Hayati Rezvan et al. 2018), which is what this function does via
`mice`'s `post` argument. Each rung re-imputes from the `mids` object's
stored settings – never from its recorded `call`, which does not resolve
outside the function that built it.

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

- Continuous targets only; see Details for categorical.

- With `pmm` (mice's default), shifted values may fall outside the
  observed range that `pmm` otherwise guarantees. A message is emitted
  once.

- The curve assumes the supplied imputation model is compatible with the
  mediation model; missingmed cannot verify this.

## See also

[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[MDSensitivityResult](https://data-wise.github.io/missingmed/reference/MDSensitivityResult.md)
