# Fit the mediation model across imputations

Runs the mediation specification held in an
[MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
object on every imputed dataset, delegating each fit to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).
The result is an
[MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
whose `per_imputation` slot is a list of **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects (one per imputation) — the shape consumed by both Rubin's-rules
pooling
([`pool()`](https://data-wise.github.io/missingmed/reference/pool.md))
and D4-stacked MBCO
([`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)).

## Usage

``` r
run(object, ...)
```

## Arguments

- object:

  An
  [MDMediationData](https://data-wise.github.io/missingmed/reference/MDMediationData.md)
  object.

- ...:

  Additional arguments forwarded to
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).

## Value

An
[MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
object.

## Details

It is the S7 successor of the S4
[`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md)
method.

## See also

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md),
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md)
