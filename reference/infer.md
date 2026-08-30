# Inference on the indirect effect under multiple imputation

Computes inference for the indirect (mediated) effect from a fitted
missingmed pipeline, dispatching to one of two engines:

## Usage

``` r
infer(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
  (supports both `"mc"` and `"mbco"`) or an
  [MDMediationResult](https://data-wise.github.io/missingmed/reference/MDMediationResult.md)
  (supports `"mc"`).

- ...:

  Method arguments: `type` (inference type, `"mc"` (default) or
  `"mbco"`), `level` (confidence level for `"mc"`, default `0.95`), and
  `n.mc` (Monte-Carlo draws for `"mc"`, default `1e5`).

## Value

For `"mc"`, the list returned by
[`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html).
For `"mbco"`, a named numeric vector `c(D4, p, r4, nu, d_S)`.

## Details

- `type = "mc"` — Monte-Carlo / distribution-of-the-product confidence
  interval via
  [`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
  applied to the **pooled** named
  [medfit::MediationData](https://rdrr.io/pkg/medfit/man/MediationData.html).

- `type = "mbco"` — **D4-stacked MBCO** likelihood-ratio test of \\H_0:
  a b = 0\\, computed from the per-imputation datasets (MBCO does not
  commute with Rubin's rules; see
  [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)).

## See also

[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md),
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)
