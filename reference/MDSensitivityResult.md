# MDSensitivityResult: MNAR sensitivity curve (S7)

An S7 class holding the result of
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md):
one inference result per rung of a delta grid, plus the grid itself and
the realized marginal sensitivity parameters.

## Usage

``` r
MDSensitivityResult(
  rungs = list(),
  grid = data.frame(),
  msp = numeric(),
  target = character(0),
  type = "mc",
  seed = integer(0),
  seed_source = "argument",
  method_target = NA_character_,
  source = NULL
)
```

## Arguments

- rungs:

  List of inference results, one per row of `grid`.

- grid:

  Data frame of delta values; one column per target, one row per rung.

- msp:

  Numeric vector of realized marginal sensitivity parameters, one per
  rung, computed on the first target (`target[1]`).

- target:

  Character; the shifted variable(s).

- type:

  Inference type used for each rung (`"mc"` or `"mbco"`).

- seed:

  Integer seed pinned across rungs.

- seed_source:

  `"mids"` if taken from the supplied `mids`, `"argument"` if passed
  explicitly, `"default"` if neither was available.

- method_target:

  The `mice` imputation method(s) used for the target variable(s).

- source:

  The originating
  [MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md).

## Value

An `MDSensitivityResult` S7 object.

## The delta scale

`@grid` holds **conditional** sensitivity parameters (CSPs) – the values
the user supplied. `@msp` holds the **marginal** sensitivity parameter
actually realized at each rung: the mean difference between imputed and
observed values of the target. They are not the same quantity and can
differ substantially; see
[`vignette("technical")`](https://data-wise.github.io/missingmed/articles/technical.md)
and
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md).

## See also

[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
