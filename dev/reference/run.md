# Fit the mediation model across imputations

Runs the mediation specification held in an
[MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
object on every imputed dataset, delegating each fit to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).
The result is an
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
whose `per_imputation` slot is a list of **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects (one per imputation) — the shape consumed by both Rubin's-rules
pooling
([`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md))
and D4-stacked MBCO
([`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)).

## Usage

``` r
run(object, ...)
```

## Arguments

- object:

  An
  [MDMediationData](https://data-wise.github.io/missingmed/dev/reference/MDMediationData.md)
  object.

- ...:

  Additional arguments forwarded to
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html).

## Value

An
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
object.

## Details

An engine error is rethrown with the engine and the imputation it failed
on. Engine warnings (a `glm` that did not converge, fitted probabilities
of 0 or 1) are collected and raised once, naming the imputations that
produced them.

It is the S7 successor of the S4
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md)
method.

## See also

[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md),
[`run_sem()`](https://data-wise.github.io/missingmed/dev/reference/run_sem.md)
