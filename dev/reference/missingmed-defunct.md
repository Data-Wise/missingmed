# Defunct S4 functions

These functions belonged to the S4 interface, which was removed in
missingmed 0.6.0. Each one now stops with a message naming its
replacement. See `vignette("s4-migration", package = "missingmed")`.

## Usage

``` r
set_sem(...)

run_sem(...)

pool_sem(...)

fit_model(...)

lav_mice(...)

mx_mice(...)
```

## Arguments

- ...:

  Ignored.

## Value

Never returns; always an error of class `defunctError`.

## Details

|  |  |
|----|----|
| Defunct | Replacement |
| `set_sem()` | [`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md), with `engine = "lavaan"` for a structural equation model |
| `run_sem()` | [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md) |
| `pool_sem()` | [`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md) |
| `fit_model()`, `lav_mice()` | [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md) fits every imputation |
| `mx_mice()` | none: OpenMx models are no longer supported |
