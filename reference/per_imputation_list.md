# Access the per-imputation mediation fits (for MBCO)

Returns the list of per-imputation **named**
[medfit::MediationData](https://rdrr.io/pkg/medfit/man/MediationData.html)
objects held in an
[MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md),
together with the number of imputations `m`.

## Usage

``` r
per_imputation_list(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
  object.

- ...:

  Unused.

## Value

A list with components `per_imputation` (a length-`m` list of named
[medfit::MediationData](https://rdrr.io/pkg/medfit/man/MediationData.html))
and `m` (the number of imputations).

## Details

This accessor exists because **MBCO does not commute with Rubin's
rules**: D4-stacked MBCO needs the per-imputation fits, not the pooled
estimate. The list it returns is the shape consumed by
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)`(type = "mbco")`
and by an external
[`RMediation::mbco()`](https://data-wise.github.io/rmediation/reference/mbco.html)
MI entry point (missingmed issue \#2).

## See also

[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
