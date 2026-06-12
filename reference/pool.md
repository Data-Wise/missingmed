# Pool per-imputation mediation fits with Rubin's rules

Applies Rubin's (1987) rules to the list of per-imputation **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects in an
[MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md),
producing a single pooled named
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
(the `pooled` slot of the returned
[MDMediationResult](https://data-wise.github.io/missingmed/reference/MDMediationResult.md)).
Because the estimates and variance-covariance carry the mediation path
names (`a`, `b`, `c_prime`, ...), the pooled object is valid input to
[`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
/
[`RMediation::medci()`](https://data-wise.github.io/rmediation/reference/medci.html).

## Usage

``` r
pool(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/reference/MDMediationFit.md)
  object.

- ...:

  Unused.

## Value

An
[MDMediationResult](https://data-wise.github.io/missingmed/reference/MDMediationResult.md)
object.

## Details

Pooling math (migrated from the S4 `pool_sem` / `pool_tidy` /
`pool_cov`): \$\$\bar Q = \frac{1}{m}\sum_i Q_i, \quad \bar U =
\frac{1}{m}\sum_i U_i, \quad B = \mathrm{cov}(Q_1, \ldots, Q_m), \quad T
= \bar U + (1 + 1/m) B.\$\$

It is the S7 successor of the S4
[`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)
method.

## References

Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in Surveys*.
Wiley.

## See also

[`run()`](https://data-wise.github.io/missingmed/reference/run.md),
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)
