# SemImputedData Class

An S4 class to hold multiply imputed datasets for structural equation
modeling (SEM) analysis. It facilitates working with imputed data from
the `mice` package and supports SEM analysis using either the `lavaan`
or `OpenMx` packages.

## Slots

- `data`:

  An object of class `mids` from the `mice` package, representing
  multiply imputed datasets.

- `model`:

  A `lavaan` or `OpenMx` model syntax to be used for SEM analysis. For
  `lavaan` models, the syntax should be a character string as described
  in
  [lavaan::model.syntax](https://rdrr.io/pkg/lavaan/man/model.syntax.html).
  For `OpenMx` models, the syntax should be an
  [OpenMx::mxModel](https://rdrr.io/pkg/OpenMx/man/mxModel.html) object
  with or without
  [`OpenMx::mxData()`](https://rdrr.io/pkg/OpenMx/man/mxData.html)
  specified; that is, `mxModel` syntax can be without data specified. In
  addition, both `lavaan` and `OpenMx` models can be a fitted model
  object in the respective package.

- `method`:

  A character string indicating the SEM package to be used for analysis.
  It is a derived slot from the `model` slot, and it is set
  automatically based on the class of the `model` slot. The possible
  values are "lavaan" or "OpenMx".

- `conf_int`:

  A logical value indicating whether confidence intervals are included
  in the SEM results. Defaults to `FALSE`.

- `conf_level`:

  A numeric value specifying the confidence level for confidence
  intervals, which must be between 0 and 1. Defaults to 0.95.

- `original_data`:

  A derived (from mids object) slot to store the original data used to
  create the imputed datasets.

- `n_imputations`:

  A derived (from mids object) slot to store the number of imputations
  used to create the imputed datasets.

- `fit_model`:

  SEM fitted to the original data with list wise deletion of missing
  data.

## Author

Davood Tofighi <dtofighi@gmail.com>
