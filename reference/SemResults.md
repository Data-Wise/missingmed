# SemResults Class

An S4 class for storing the results of SEM analysis performed on
multiply imputed datasets. Supports `lavaan` and `OpenMx`.

## Slots

- `results`:

  A list of SEM model fits for each imputed dataset.

- `estimate_df`:

  Data frame of parameter estimates and standard errors.

- `coef_df`:

  Data frame of coefficient estimates for each imputed dataset.

- `cov_df`:

  List of covariance matrices of coefficient estimates.

- `method`:

  SEM package used for analysis: 'lavaan' or 'OpenMx'.

- `conf_int`:

  Logical; if confidence intervals are included.

- `conf_level`:

  Confidence level for confidence intervals.

## Author

Davood Tofighi <dtofighi@gmail.com>
