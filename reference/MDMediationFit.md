# MDMediationFit: per-imputation mediation fits (S7)

An S7 class holding the result of fitting a mediation model across all
imputations. Its defining feature is `per_imputation`: a list of
**named**
[medfit::MediationData](https://rdrr.io/pkg/medfit/man/MediationData.html)
objects, one per imputation. This list is what the MBCO-MI path
consumes, because MBCO does not commute with Rubin's rules (D4-stacked
MBCO needs the per-imputation fits, not the pooled estimate).

## Usage

``` r
MDMediationFit(
  per_imputation = list(),
  fits = list(),
  m = integer(0),
  engine = "glm",
  conf_int = FALSE,
  conf_level = 0.95,
  weights = NULL,
  source = NULL
)
```

## Arguments

- per_imputation:

  A list of named
  [medfit::MediationData](https://rdrr.io/pkg/medfit/man/MediationData.html)
  objects (length `m`).

- fits:

  A list of the raw backend fits (`lavaan`/`OpenMx`), one per
  imputation.

- m:

  Integer number of imputations.

- engine:

  medfit fitting engine used (e.g. `"glm"`).

- conf_int:

  Logical; whether output carries confidence intervals.

- conf_level:

  Numeric in (0, 1); confidence level.

- weights:

  (IPW) Full-length numeric IPW weight vector (`NA` for dropped rows);
  `NULL` for MI fits.

- source:

  The originating
  [MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
  (retained so MBCO can refit constrained/unconstrained models against
  the imputed data).

## Value

An `MDMediationFit` S7 object.

## Details

It is the S7 successor of the S4
[SemResults](https://data-wise.github.io/missingmed/reference/SemResults.md)
class.

## See also

[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md),
[SemResults](https://data-wise.github.io/missingmed/reference/SemResults.md)
