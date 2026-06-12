# MDMediationResult: pooled mediation result (S7)

An S7 class holding the Rubin's-rules pooled mediation result. Its
defining feature is `pooled`: a single **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
built from the pooled estimates and total variance-covariance, valid as
input to
[`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
/
[`RMediation::medci()`](https://data-wise.github.io/rmediation/reference/medci.html)
(path coefficients resolve by name). It is the S7 successor of the S4
[PooledSEMResults](https://data-wise.github.io/missingmed/reference/PooledSEMResults-class.md)
class.

## Usage

``` r
MDMediationResult(
  pooled = NULL,
  tidy_table = data.frame(),
  cov_total = NULL,
  cov_between = NULL,
  cov_within = NULL,
  m = integer(0),
  engine = "glm",
  conf_int = FALSE,
  conf_level = 0.95
)
```

## Arguments

- pooled:

  A named
  [medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
  carrying the pooled estimates and total vcov (path labels `a`, `b`,
  `c_prime`, ...).

- tidy_table:

  A data frame of pooled estimates (term, estimate, std_error, p_value,
  var_w, var_b, var_tot).

- cov_total, cov_between, cov_within:

  The Rubin's-rules total, between-, and within-imputation covariance
  matrices.

- m:

  Integer number of imputations pooled.

- engine:

  medfit fitting engine used (e.g. `"glm"`).

- conf_int:

  Logical; whether the tidy table carries confidence intervals.

- conf_level:

  Numeric in (0, 1); confidence level.

## Value

An `MDMediationResult` S7 object.

## See also

[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md),
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md),
[PooledSEMResults](https://data-wise.github.io/missingmed/reference/PooledSEMResults-class.md)
