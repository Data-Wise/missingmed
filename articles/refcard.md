# Reference card

One page to look things up. Every cell of the matrix and every message
in the catalog below is checked by the package tests, so this page
cannot drift from what the code does.

## The pipeline

| Verb | Takes | Returns |
|----|----|----|
| [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md) | a [`mice::mids`](https://amices.org/mice/reference/mids.html) (`method = "mi"`) or a data frame (`method = "ipw"`), the model, the roles | `MDMediationData` |
| [`run()`](https://data-wise.github.io/missingmed/reference/run.md) | `MDMediationData` | `MDMediationFit`: one fit per imputation |
| [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) | `MDMediationFit` | `MDMediationResult`: Rubin’s-rules estimates |
| [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md) | a fit (`"mc"`, `"mbco"`) or a pooled result (`"mc"`) | an interval, or an `MbcoMIResult` test |

[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
runs the MBCO test on a plain list of completed data frames, and
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
repeats the analysis with shifted imputed values.

## What works where

Each row is an engine and method. A check mark means the call runs; a
cross means it is refused with a message from the catalog below.

| Engine, method | `infer(type = "mc")` | `infer(type = "mbco")` | [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md) (mc) | `sensitivity_mnar(type = "mbco")` |
|----|----|----|----|----|
| `glm`, MI | ✔ | ✔ | ✔ | ✔ |
| `regmedint`, MI | ✔ | ✔ | ✔ | ✔ |
| `lavaan`, MI | ✔ | ✔ | ✔ | ✔ |
| `glm`, IPW | ✔ | ✘ | ✘ | ✘ |
| `lavaan`, IPW | ✔ | ✘ | ✘ | ✘ |

Notes:

- `regmedint` needs medfit 0.4.0 or later and `method = "mi"`. Its MBCO
  test refits with [`glm()`](https://rdrr.io/r/stats/glm.html), which
  matches it for the Gaussian and binomial models it accepts.
- MBCO with `lavaan` is maximum likelihood only: `estimator = "MLR"`,
  `"MLM"`, `"WLSMV"`, and `group`, `ordered` and `sampling.weights` in
  `fit_args` are refused, naming the option.
- IPW has no imputations, so it has no MBCO test and no delta
  sensitivity analysis.

## Setting up a model

|  | formula path (`glm`, `regmedint`) | lavaan path |
|----|----|----|
| model | `formula_y`, `formula_m` | `model` (lavaan syntax) and `outcome` |
| roles | `treatment`, `mediator` | `treatment`, `mediator` (may be latent) |
| families | `family_y`, `family_m` | none: set options in `fit_args` |
| extra fitting options | `fit_args = list(...)` | `fit_args = list(...)` (for [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html)) |

Pass fitting options with `fit_args` in
[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md).
Passing them through `run(...)` or `sensitivity_mnar(...)` still works
but warns (class `md_dots_deprecated`).

## Errors and warnings

| Condition | Message contains | Fix |
|----|----|----|
| arguments passed through `run(...)` | `is deprecated and will` | set them with `fit_args` in [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md) |
| a lavaan fit did not converge in [`run()`](https://data-wise.github.io/missingmed/reference/run.md) | `did not converge on imputation` | simplify the model, or `fit_args = list(control = list(iter.max = 5000))` |
| MBCO: a glm refit did not converge | `model did not converge` | rescale variables, merge sparse factor levels; the data may be separated |
| MBCO: a glm refit has a non-finite log-likelihood | `non-finite log-likelihood` | check the data for degenerate columns |
| MBCO: a lavaan refit did not converge | `lavaan model did not converge` | as for [`run()`](https://data-wise.github.io/missingmed/reference/run.md) |
| MBCO: improper solution in a refit (warning) | `improper solution` | check the model for a negative variance or a boundary estimate; the test proceeds |
| MBCO with IPW | `MBCO inference for IPW is not yet implemented` | use `type = "mc"` |
| MBCO with a lavaan estimator other than ML | `supports estimator = "ML" only` | use `type = "mc"`, or refit with ML |
| MBCO with fewer than two imputations | `at least 2 imputations` | re-impute with `m >= 2` |
| MBCO: missing values in a variable the constraint drops | `which the MBCO constraint drops` | impute every model variable |
| MBCO: the constraint removes a different number of parameters across imputations | `Under ariv = "fixed"` | drop or merge the sparse factor level |
| [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md) with IPW | `not available for method = "ipw"` | use `method = "mi"` |
| a failing MBCO refit inside a sensitivity sweep | `sensitivity rung` | narrow the `delta` grid; the message names the rung and delta |
| latent mediator and no `target` in [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md) | `` `target` is required `` | name an observed indicator in `target` |

## Where to read more

- the test:
  [`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md);
  the options:
  [`?mbco_d4`](https://data-wise.github.io/missingmed/reference/mbco_d4.md);
  the result:
  [`?MbcoMIResult`](https://data-wise.github.io/missingmed/reference/MbcoMIResult.md)
- structural equation models: the *Structural equation models* article
- choosing between engines and methods: the *Choosing an analysis*
  article
