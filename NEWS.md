# missingmed (development version)

# missingmed 0.9.0

## New features

* `sensitivity_mnar()` gains `on_error = c("stop", "continue")`. The default,
  `"stop"`, aborts at the first rung whose fit or inference fails, as before. With
  `"continue"` the rungs that worked are kept: a failed rung reads as `NA`, its
  message is in the new `@failed` property and in an `error` column of `tidy()`,
  one warning names the failed rungs, and `summary()` reports the tipping point as
  undetermined when a failed rung could change it. It is an error if every rung
  fails. Re-imputation errors always stop.
* A failure in `run()` or `infer(type = "mc")` at a rung now carries the same
  "sensitivity rung i of n (delta ...)" prefix that the MBCO failure already had.
* **Breaking change to the IPW missingness model** (`method = "ipw"`). When two
  or more model variables are incomplete, the default `weight_formula = NULL`
  and a named `weight_formula = list(...)` now fit a **sequential
  (chain-rule)** model: P(all observed | Z) = P(V1 observed | Z) x P(V2
  observed | V1 observed, Z) x ..., each factor fitted only on the rows where
  the earlier variables are observed. The default orders the incomplete
  variables by ascending share of missing values (ties in model-variable order)
  and uses the fully observed model variables as predictors; a list is the
  sequence in list order. A factor that is observed wherever the earlier
  variables are (the second factor when the variables go missing together) has
  probability 1 and fits no model. A single formula still fits one joint model,
  and a model with only one incomplete variable gives the same weights as
  before. Why: the joint model (the old default) is biased at any sample size
  when the variables go missing separately (about -0.02 in `b` in the simulated
  check), and the old per-variable list, which fitted each variable on all
  rows, is biased when they go missing together (about +0.05). The sequential
  form was unbiased in independent, simultaneous and monotone missingness in a
  162-cell simulation (largest bias in `b` 0.004 at n = 5000); at n <= 500 its
  RMSE of `b` is 3% to 13% above the joint model's where the two differ. The
  order matters under monotone missingness (a reversed order was biased,
  -0.012). `docs/specs/SPEC-ipw-missingness-default-2026-10-09.md`.

## Bug fixes

* `engine = "lavaan"`: `run()` now reads the a, b and c' paths by role
  (`treatment`, `mediator`, `outcome`). Before, a model that labeled a covariate
  path `a`, `b` or `cp` (for example `M ~ am*X + a*C`) made medfit take that path
  as the a path, so `infer(type = "mc")` targeted a different indirect effect than
  `infer(type = "mbco")`. `set_md_mediation()` now refuses the labels `a`, `b` and
  `c_prime` on any path other than their own, and `run()` checks the extracted
  estimates against the fit's parameter table.
* `infer(type = "mbco")` stops, instead of testing an unweighted model, when
  `fit_args` holds `weights`, `offset`, `subset` or `na.action`: the MBCO refits
  use a plain `glm()`, so a p-value would have described a different model than
  the one `run()` fitted. `type = "mc"` is unaffected, and `control` and `start`
  still pass. In `sensitivity_mnar(type = "mbco")` the refusal reads as a failed
  rung under `on_error = "continue"`.
* The D4 test (`infer(type = "mbco")`, `mbco_d4()`, `sensitivity_mnar(type =
  "mbco")`) now refers the statistic to `F(k, nu)` with the denominator degrees of
  freedom of Chan and Meng (2022, eq. 2.15), `nu = k (K - 1) (1 + 1 / r4)^2`, the
  same as `mitml::testModels(method = "D4")`. Earlier versions used the Li et al.
  (1991) df, which Chan and Meng show approximates this test worse. `D4` and `r4`
  are unchanged; `nu` is larger and `p` slightly smaller when `k (K - 1) > 4`
  (for example K = 20, k = 1: `nu` 62.6 -> 83.1, p 0.0422 -> 0.0412 on the probe
  data). For K = 5 and k = 1 the two formulas coincide. The 0.8.0 test was
  slightly conservative relative to the published procedure; the size gap at
  K = 20 is at most about 0.002.
* `run()` with `method = "ipw"` and a per-variable `weight_formula = list(...)` now
  refuses a list that omits an incomplete model variable. Complete cases are selected on every
  incomplete variable, so weights built from a subset left the rest of the selection
  uncorrected and still returned plausible estimates and standard errors. The error
  names the missing variables. A list that covers every incomplete variable, a single
  formula, and the default are unchanged; an analysis that relied on the old
  behavior must now name the missing variable (for example `Y = ~ X + C`).

## Documentation

* **`ariv = "own"` can be liberal.** A calibration of the glm engine (132 settings,
  1000 replications each) found the default `"fixed"` at or below 5.7% rejection of
  a true null everywhere, while `"own"` exceeded 6.5% in 23 of 80 non-Gaussian
  settings (up to 13.8%) and, in a separate plain-Gaussian grid, reached 8.3% at
  n = 200 with 40% missing. `?mbco_d4`, `vignette("mbco-mi")` and the FAQ now say so
  and recommend `"fixed"` unless you need to reproduce an earlier analysis. The
  operating-characteristics table covers the glm engine.
* The IPW article now says what the simulations showed about the missingness model
  and the standard errors: the default joint model is biased at any sample size when
  several variables are missing for separate reasons (a per-variable `weight_formula`
  removes that), trimming added bias in that setting, a finite-sample bias remains at
  a few hundred complete cases, and the weight-estimation uncertainty is still not
  propagated. The figures come from `dev/sim-ipw-auxm-bias.R` and the 48-setting
  coverage run.
* The lavaan tutorial gains a section on lavaan 0.7-3's `information_meat_hc` and
  `information_bread` (small-sample sandwich standard errors): they work through
  `fit_args` with `method = "ipw"` (`"HC1"` only) and with a robust estimator such
  as `"MLR"`, and are ignored under plain ML.
* The documentation no longer says `"own"` "reproduces" missingmed 0.4.0 or the
  research prototype: `D4`, `r4` and the branch still match, but `nu` and `p` differ
  slightly since the denominator degrees of freedom changed (see Bug fixes).

## Lifecycle

* missingmed now uses the lifecycle package. The deprecations of `run(...)` and
  `sensitivity_mnar(...)` extra arguments (0.7.0) and of `set_md_mediation(mechanism =
  "mnar")` (0.3.0) warn through `lifecycle::deprecate_warn()`: once per session by
  default, and every time with `options(lifecycle_verbosity = "warning")`. **The
  warning class changes** from `md_dots_deprecated` to `lifecycle_warning_deprecated`
  (the dots warning was introduced in 0.7.0); code that caught the old class should
  catch the new one.
* Stage badges on the help pages: `sensitivity_mnar(on_error =)` is experimental and
  the deprecated arguments are badged; the lavaan engine and its MBCO are stable
  (maximum likelihood only; the refusals for `MLR`, `group`, `ordered` and
  `sampling.weights` are documented scope limits). `?missingmed-package` has a *Lifecycle* section.

# missingmed 0.8.0

## New features

* **MBCO for `engine = "lavaan"`.** `infer(type = "mbco")` and
  `sensitivity_mnar(type = "mbco")` now work for lavaan fits, including a latent
  mediator, with the same D4-stacked test, `MbcoMIResult` and `ariv` options as
  the glm engine. On an observed-variable model it agrees with the glm engine to
  numerical precision. The tested paths are the structural regressions `mediator
  ~ treatment` (a) and `outcome ~ mediator` (b); a latent mediator's measurement
  model and any direct effects of its indicators stay free. Only `estimator =
  "ML"` is supported: `MLR`, `MLM`, `WLSMV`, `group`, `ordered` and
  `sampling.weights` are refused, naming the option. A non-converged refit
  refuses; an improper solution warns once.
* `mbco_d4()` gains `model`, `outcome` and `fit_args` for a lavaan model on a
  plain list of data frames. `model` cannot be combined with `formula_y`,
  `formula_m` or the families.

## Bug fixes

* `infer(type = "mbco")` and `mbco_d4()` now refuse when a `glm()` refit did not
  converge or has a non-finite log-likelihood, instead of returning a p-value
  computed from it. The error names the dataset (imputation or stacked data),
  the branch (`full`, `a = 0`, `b = 0`) and the model. `sensitivity_mnar(type =
  "mbco")` names the failing rung and delta. Converged fits are unchanged.

# missingmed 0.7.0

## Deprecations

* Passing arguments through `run(...)` or `sensitivity_mnar(...)` is deprecated:
  set them with the new `fit_args` of `set_md_mediation()`. They are still
  forwarded, with a warning (class `md_dots_deprecated`; `sensitivity_mnar()` warns
  once, not once per rung), and a name that is already in `fit_args` is an error.
  `sensitivity_mnar()` now reads the stored `fit_args`, so its refits reproduce the
  original fit's options without restating them.

## New features

* `fit_args` (a named list stored on the object) now works for the `glm` and
  `regmedint` engines, where it goes to `medfit::fit_mediation()` (it already
  existed for `engine = "lavaan"`, where it goes to `lavaan::sem()`). It cannot
  restate what `set_md_mediation()` passes itself (`formula_y`, `formula_m`, `data`,
  `treatment`, `mediator`, `engine`, `family_y`, `family_m`; on the IPW path also
  `weights` and `se_type`).
* `outcome` is optional for the `glm` engines: it defaults to the response of
  `formula_y` and, when given, must match it (it stays required for lavaan).

## Breaking changes

* The `.Defunct()` stubs for the removed S4 API are deleted: `set_sem()`,
  `run_sem()`, `pool_sem()`, `fit_model()`, `lav_mice()` and `mx_mice()` are no
  longer exported, so calling one now gives R's "could not find function" error
  instead of a message naming the replacement. The replacements are unchanged:
  `set_md_mediation()`, `run()` and `pool()`, with `engine = "lavaan"` for a
  structural equation model; see `vignette("s4-migration")`. The help page
  `?"missingmed-defunct"` is gone with them.

## Licensing and dependencies

* missingmed is now licensed GPL (>= 3) (was GPL-2), matching `medfit`,
  `RMediation` and `medsim`, which missingmed already imports.
* `lavaan (>= 0.7-3)` is required (was `>= 0.6-0`). lavaan 0.7-2 could return a
  fit marked converged that broke its own constraints (`optim_parscale =
  "standardized"`, also used in the automatic retries), and could report
  convergence for a runaway solution; 0.7-3 fixes both.

## Bug fixes

* `pool()` for `engine = "lavaan"` no longer blanks the Wald test of a covariance
  between two different variables (for example the residual covariance
  `Y~~Y2`). Only variances (`M~~M`) keep an `NA` statistic and p-value, because
  their null lies on the boundary; a covariance's null is interior, so its
  z-test is valid. Found by an adversarial review of 0.6.0.

* `set_md_mediation(method = "ipw", engine = "lavaan")` now guards every spelling
  of the options it controls. lavaan >= 0.7-2 accepts `sampling_weights` as well
  as `sampling.weights`; `fit_args = list(sampling_weights = ...)` used to pass the
  check and be dropped silently in favor of the IPW weights, and is now an error.
  `se = "robust_huber_white"` (or any case) is accepted as the robust SE request.
  The lavaan call itself uses the snake_case names.

# missingmed 0.6.0

## Breaking changes

* The S4 API is removed. `set_sem()`, `run_sem()`, `pool_sem()`, `fit_model()`,
  `lav_mice()` and `mx_mice()` now stop with a message naming their replacement
  (`.Defunct()` stubs, deleted in 0.7.0): use `set_md_mediation()`, `run()` and
  `pool()`, with `engine = "lavaan"` for a structural equation model. Removed
  without a stub, because nothing in the S7 pipeline uses them: the classes
  `SemImputedData`, `SemResults` and `PooledSEMResults`; the functions
  `is_fit()`, `is_pd()`, `is_lav_syntax()` and `is_valid_lav_syntax()`; and the
  `tidy()` methods for OpenMx models and `logLik` objects. There is no OpenMx
  engine: `OpenMx` is no longer imported, and `dplyr` and `purrr` are no longer
  imported either. `n_imp()` stays, now a plain function. See *Migrating from
  the S4 API* on the package website.

## New features

* `set_md_mediation()` gains `engine = "lavaan"`: give a structural equation
  model as lavaan syntax in `model`, name the `outcome`, and pass extra
  `lavaan::sem()` arguments in `fit_args` (for example `list(estimator =
  "MLR")`). The model is validated before any fitting. `run()` fits each
  imputation with lavaan; `pool()` reports z-tests (`df = Inf` at `m = 1`) and
  leaves the statistic and p-value of variance and covariance rows (`~~`) `NA`;
  `infer(type = "mc")` works. `infer(type = "mbco")` refuses for lavaan fits
  until a separate SEM-MBCO design lands. Non-convergence in any imputation
  refuses, naming the imputations; an improper solution warns once.
* `engine = "lavaan"` also works with `method = "ipw"`: the complete cases are
  fit with `sampling.weights` and always with robust (sandwich) SEs. A
  non-robust `se`, an estimator without sandwich SEs, or `se_type = "model"`
  is refused. `sensitivity_mnar()` accepts lavaan fits for `type = "mc"`; a
  latent mediator needs an explicit observed `target`.

## Documentation

* New articles on the package website: *Supported models* (every model rule
  of `set_md_mediation()`, each one run when the site builds), *Frequently
  asked questions*, and *Migrating from the S4 API*.
* `vignette("technical")` gains section 3A on models with a
  treatment-by-mediator interaction: the estimand behind `treatment_level`,
  and how `pool()` recomputes the four-way decomposition from one pooled
  reference profile.
* `run()`, `pool()`, `per_imputation_list()`, `n_imputations()` and
  `sensitivity_mnar()` have runnable examples, and the `set_md_mediation()`
  example now runs. The `pool()` help page's note on the tidy table's Wald
  columns moved from *See also* to *Details*.

# missingmed 0.5.1

## New features

* `infer(type = "mc")` supports models with a treatment-by-mediator
  interaction (`Y ~ X * M + ...`) through a new `treatment_level` argument
  (#20). The indirect effect there is `a * (b + theta3 * x)`, so the interval
  is for the treatment level `x` you choose (for a 0/1 treatment, `1` is the
  total and `0` the pure natural indirect effect); it is drawn from the pooled
  estimates and pooled covariance of `a`, `b` and `theta3` with
  `RMediation::ci()`, and the result names the estimand in `Estimand`.
  `treatment_level` is required for such models and an error elsewhere.
  `sensitivity_mnar(type = "mc")` passes it through.

* `sensitivity_mnar()` gains `ariv`, passed to `infer(type = "mbco")` for
  every rung (it was always `"fixed"`); `print()` of an MBCO curve shows it.

* `infer()` and `sensitivity_mnar()` warn, naming them, about arguments that
  do not apply to the chosen `type` (`level`, `n.mc` and `treatment_level`
  for `"mbco"` in `infer()`; `ariv` for `"mc"`), instead of ignoring them.

* New vignette, `vignette("worked-analysis")`: a step-by-step tutorial of a
  mediation analysis with a missing mediator (complete-data reference, MAR
  deletion, imputation, pooled Monte Carlo interval, D4-MBCO test with both
  `ariv` choices, MNAR sensitivity), with a second part showing what was
  added after 0.5.0.

* `set_md_mediation(conf_int = TRUE)` now does what it documented: `pool()`
  adds per-coefficient `conf_low` and `conf_high` columns to the pooled tidy
  table, at `conf_level` on Rubin's t reference. Before, the argument was
  stored and ignored.

## Bug fixes

* `set_md_mediation()` now validates the model before fitting; previously a
  `formula_m` whose LHS was not `mediator` returned a wrong indirect effect
  silently. It also refuses terms the pipeline cannot pool correctly: the
  treatment and mediator may enter only as main effects, plus one `X:M` term
  in `formula_y` (products such as `X:C` or `M:W`, transforms such as
  `I(X^2)` or `log(M)`, and offsets involving either are refused, with a
  pointer to `mbco_d4()` for moderated models); an `X:M` term with a
  non-Gaussian or non-identity-link `family_y` or `family_m`; and a
  non-numeric treatment
  (factor, character or logical; recode to numeric).

* `mbco_d4()` now refuses a `formula_m` whose response involves anything but
  the mediator (`log(M) ~ X` is still accepted), and a `formula_y` whose
  response is the mediator.

* `pool()` no longer errors on models with an `X:M` term (#20). It set the
  pooled path coefficients one at a time, which broke the invariants of
  medfit's `InteractionMediationData`; it now sets them together, pools the
  interaction coefficient with Rubin's rules, and recomputes the four-way
  decomposition (`pie`, `int_med`, `nie`, ...) from the pooled paths and one
  pooled reference profile: `int_ref` uses the pooled `theta3` and the mean
  of the per-imputation mediator reference values (which differ when a
  covariate is imputed), and imputations fitted at different `m_star` are
  refused. The
  pooled `theta3` and `b0` rows now take the degrees of freedom of their
  source rows (`y_X:M`, `m_(Intercept)`).

* `print()` and `summary()` of a pooled `X:M` fit report the indirect effect
  at `x = 0` and `x = 1` instead of a single `a*b`, which is the `x = 0`
  value only.

* `pool_sem()` (deprecated) reported the geometric mean of the
  per-imputation p-values, which is not a valid pooled test. It now reports
  Rubin's pooled Wald `statistic`, `df` and `riv`, the p-value of the t test on
  those degrees of freedom, and, with `conf_int = TRUE` in `set_sem()`,
  `conf_low` and `conf_high` (which were documented but never computed).

* `summary()` of a sensitivity curve with NA rungs still reports the tipping
  point when every NA rung lies farther from MAR than it, since the unknown
  verdicts cannot change it; it declines (`undetermined = TRUE`) only when an
  NA rung could. `sensitivity_mnar()` records a fractional `seed` as the
  integer `set.seed()` used.

* The S7 classes validate more of their input, turning silent wrong answers
  and obscure late crashes into clear errors at construction:
  `MDMediationData` refuses `treatment == mediator`, missing or empty roles,
  an `engine` that is not a single string, an IPW `weight_stabilize` that is
  not `TRUE`/`FALSE` (it used to fit unstabilized weights silently), an NA
  `weight_trim`, and an `n_imputations` that disagrees with the data;
  `MDMediationFit` and `MDMediationResult` refuse non-fit objects and an NA
  `m`; `MDSensitivityResult` refuses zero rungs, rungs whose shape does not
  match `type`, and a `level` outside (0, 1). `print()` of a result with an
  empty table no longer errors, and `summary()` of a sensitivity curve with
  NA rungs lists them (new `na_rungs` element) and declines to name a
  tipping point.

* Engines are checked when the model is set up: `engine` must be one of the
  engines missingmed supports with the installed medfit (`"glm"`, plus
  `"regmedint"` with medfit >= 0.4.0 and the MI estimator); anything else,
  including `"lavaan"` (planned for 0.6.0; `set_sem()` exists today), errors
  in `set_md_mediation()` instead of inside `run()`. A failed fit is reported
  as `engine "glm" failed on imputation i of m: ...`, keeping the original
  message, and fitting warnings are collected into one warning naming the
  imputations.

* `pool()` aligns the per-imputation estimates and covariance matrices by
  name; imputations whose coefficients came in a different order were stacked
  by position and silently scrambled every pooled estimate. Imputations with
  different coefficient sets are refused, naming the terms, and a pooled `b`
  that is NA (an aliased mediator) gets a clear error.

* `run()` warns when a mids leaves a model variable incomplete, since each
  imputation is then fitted on its complete cases. `Y ~ .` now works in
  `set_md_mediation()`, `run()`, `mbco_d4()` and `infer(type = "mbco")`.
  A non-syntactic treatment or mediator name (for example `` `my M` ``),
  which medfit cannot fit, is refused at set-up.

* IPW: with no missing data the weights are exactly 1 without fitting a
  degenerate response model (no more non-convergence warnings); zero complete
  cases, a `weight_formula` that is not a formula or named list of formulas,
  uses `.`, or names absent variables, and an NA `weight_trim`,
  `weight_stabilize` or `conf_int` are refused at set-up. Names in a
  `weight_formula` now resolve in the formula's environment.

* `infer()` refuses a `level` outside (0, 1) (0 gave a zero-width interval),
  an `n.mc` below 2 or not a whole number, and unknown arguments in `...`
  (for example `conf.level = 0.9` was silently ignored and a 95% interval
  returned).

* `sensitivity_mnar()` checks `seed` and `level` before re-imputing, and
  refuses a delta grid with duplicate or empty column names (a duplicate
  name silently reported the wrong rung) and a delta matrix with more than
  one column. `seed = NA` is refused because it made the curve
  irreproducible.

* `mbco_d4()` and `infer(type = "mbco")` refuse imputations that differ in
  row count, columns, or a model variable's type, and NA left in a model
  variable (which silently dropped different rows per model); a failed fit
  names its imputation. When the imputations are identical, `r4` is now
  exactly 0 and `nu` is `Inf` instead of rounding noise.

* The deprecated S4 pipeline works again: `run_sem()` failed on every call
  (an internal `lav_mice()`/`mx_mice()` with swapped arguments was masked by
  the exported functions), and `lav_mice()` rejected every valid model
  syntax (an inverted check). `fit_model()` and `set_sem()` list the
  accepted model types for anything else; a lavaan or OpenMx failure names
  its imputation, and per-imputation warnings are collected into one.
  `pool_sem()` needs at least two imputations (with one, every standard
  error was NA), `is_pd()` returns `FALSE` for a non-symmetric matrix,
  `PooledSEMResults` requires its four base columns, `set_sem()` refuses a
  `conf_level` of 0 or 1, and `mx_mice()` now passes `...` to
  `OpenMx::mxRun()` as documented (so unknown arguments error) and runs the
  imputations sequentially (`lapply`, not `omxLapply`).

* New tests: edge cases for every exported function, and end-to-end tests
  that check the pooled estimates, variances and degrees of freedom against
  `mice::pool()`, and MC, MBCO, IPW and sensitivity results against known
  answers.

## Documentation

* The package Description no longer calls missingmed an S4/SEM
  package; the README cites `citation("missingmed")` (new `inst/CITATION`)
  instead of a stale version string; the deprecated S4 functions say so on
  their help pages and name the 0.6.0 removal; the pkgdown site builds
  development versions under `/dev/` so the root documents the release.

# missingmed 0.5.0

## New features

* **`infer(type = "mbco")` gains `ariv = c("fixed", "own")`, default
  `"fixed"`** (#19). `ariv` sets which per-imputation statistics enter the
  relative increase in variance `r4` of the D4-stacked MBCO test:
  * `"fixed"` recomputes every imputation's statistic on the branch (`a = 0`
    or `b = 0`) that the stacked constrained fit chose. Every imputation
    then uses the stacked fit's `k`, so models whose two paths carry
    different numbers of terms (an `X:M` interaction) now return a result. A
    guard errors when the branch's constraint removes a different number of
    parameters in some imputation than in the stacked data (for example, a
    level of a factor that interacts with the treatment or mediator is absent
    from one imputation).
  * `"own"` uses each imputation's own winning branch and **reproduces earlier
    results exactly on full-rank designs**; it still refuses when the branches
    remove different numbers of parameters.

  Code that relied on the old behavior should pass `ariv = "own"`. The default
  changes results only when some imputation's own branch differs from the
  stacked fit's. `sensitivity_mnar(type = "mbco")` calls `infer()` and so uses
  the new default for its rungs. A single imputation (K = 1) is still
  an error, now pointing to complete-data MBCO.

* **New exported `mbco_d4()`**: the same test on a plain list of completed
  data frames, with `formula_y`, `formula_m`, families, `treatment`,
  `mediator` and `ariv`, so other packages can call it without `:::`.

* **New result class `MbcoMIResult`** (S7, parent `class_double`), returned by
  `infer(type = "mbco")` and `mbco_d4()`. Its data is the same named numeric
  `c(D4, p, r4, nu, d_S)`; its properties are `ariv`, `k`, `m`,
  `stacked_branch`, `branch_mix` and `p_branch_a`. It has `print()` and
  `tidy()` methods. `r["p"]`, `r[["p"]]` and `is.numeric(r)` work as before,
  and `S7::S7_data(r)` returns the old vector. Two behavior changes:
  `identical(r, old_vector)` is now `FALSE`, and `r$p` errors (the old vector
  had no `$` either).

  Reporting `branch_mix` and `p_branch_a` needs both single-path null fits in
  every imputation; the `"fixed"` statistic alone would need only the
  stacked branch's.

## Bug fixes

* The MBCO constraint's `k` (the numerator df of the D4 test) is now a rank
  difference, `rank(full) - rank(null)`, under both `ariv` values, instead of
  a column count. Nothing changes on full-rank designs. On a design with
  aliased columns, such as a factor level absent from the data, 0.4.0
  overcounted `k`, so `ariv = "own"` can now give a smaller `k` than 0.4.0 did
  there.

## Documentation

* `vignette("mbco-mi")` is retitled "Testing an indirect effect with incomplete data" and expanded into a worked guide.

# missingmed 0.4.0

## New features

* **`pool()`'s tidy table now carries a Rubin-pooled Wald test per
  coefficient**: `statistic`, `df`, `riv`, `fmi` and `p_value`. The `p_value`
  column was documented but never built. `df` is the Barnard–Rubin (1999)
  small-sample df with each model's own complete-data df (infinite for
  binomial and poisson models). At `m = 1` (IPW) it is the ordinary single-fit
  Wald test, matching `summary.glm()`. These test **one path at a time**, not
  the indirect effect; use `infer()` for that. The S4 `pool_sem()`'s
  `p_value` meant something else, a geometric mean of per-imputation p-values.

* **`sensitivity_mnar()` delegates to `mice`'s NARFCS methods** (Tompsett et
  al. 2018; Moreno-Betancur, van Buuren & White 2020). The route depends on the
  target's imputation method:
  * `norm` goes through `mnar.norm` when given a `ums` string (below). A
    numeric `delta` on a `norm` target keeps the `post` shift -- for a constant
    delta the two give identical draws (pinned by a regression test), so
    existing results do not change.
  * **A binary target imputed by `logreg` now runs** through `mnar.logreg`,
    with delta on the **log-odds** scale; it used to be refused. `delta = 0`
    reproduces the MAR analysis exactly, and `msp` is reported as a prevalence
    difference.
  * Every other method (`pmm`, `norm.nob`, `cart`, ...) keeps the `post` shift.
    Only an exact `norm`/`logreg` match is delegated: swapping `norm.boot` or
    `logreg.boot` would change the imputation method, so `delta = 0` would stop
    reproducing MAR. `logreg.boot`, `polyreg`, `polr` and `lda` targets are
    refused.

* New `ums` argument: a **covariate-varying** delta for a delegated target, one
  rung per string (e.g. `"1 + 0.5*C"`), passed verbatim to NARFCS. Every
  string is checked with a one-iteration probe before any rung runs: a string
  mice cannot parse, or one that yields NA imputations (a typo'd coefficient
  only makes mice warn), is refused and named. `summary()`
  does not compute a tipping point for a `ums` grid, because it has no numeric
  ordering.

* `MDSensitivityResult` gains `@mechanism_used` and `@scale`, one entry per
  target. `print()` and `tidy()` show them.

## Bug fixes

* **`sensitivity_mnar()` refuses a rung whose imputations are not finite.**
  If a delta or `ums` made the imputation chain produce NA, NaN or Inf, the
  fit dropped those rows and reported a complete-case result as the rung. The
  up-front `ums` check runs one iteration and cannot see failures that start
  later, so every rung is now checked after it is re-imputed.

* **A numeric 0/1 target is no longer shifted additively.** `mice` imputes a
  numeric 0/1 column with `pmm` by default, so `sensitivity_mnar()` added the
  delta to drawn 0/1 values: a gaussian mediator model then silently analyzed
  imputed 1s and 2s, and a binomial one failed late inside `glm`. A 0/1 target
  whose imputations are themselves all 0/1 (`pmm`, `cart`, `sample`, ...) is now
  refused unless it is imputed by `logreg`, which routes it to `mnar.logreg`.
  The rule reads the imputed values, not a list of methods: a normal-model
  (`norm*`) imputation of a 0/1 variable is continuous and is still allowed,
  with `delta` or `ums` alike. **Analyses that ran before now error**; that is
  the intent.

* **A non-finite `delta` is refused.** `delta = c(0, NA)` used to run, with
  that rung's imputations all NA; NA, NaN and Inf are now errors, as is a
  non-numeric column in a data-frame grid.

* **A target named like a `tidy()` column is refused.** A target named `msp`
  (or `estimate`, `conf_low`, `conf_high`, `D4`, `p_value`, `mechanism`,
  `scale`) had its delta column silently overwritten in `tidy()`.

* **`sensitivity_mnar()`'s categorical guard looked up the imputation method by
  variable name.** `mids$method` is keyed by block, so a 0/1 target imputed by
  `logreg` in a block with a non-default name slipped past the guard and got an
  additive shift on its drawn 0/1 values. The method is now resolved through
  the target's block, as the rest of the function already did.

* **The default IPW path failed without `sandwich` installed.** `method = "ipw"`
  defaults to `se_type = "sandwich"`, which `medfit` computes with
  `sandwich::vcovHC()` -- but `sandwich` is only a Suggests of `medfit` and was
  not declared by missingmed at all, so `run()` errored on a machine without it.
  `sandwich` is now in Imports.

* **`R CMD check` now runs the test suite.** `tests/testthat.R` never existed,
  so neither `R CMD check` nor CI had ever run `tests/testthat/`; adding it is
  what surfaced the `sandwich` bug above.

## Dependencies

* `medfit` and `RMediation` now install from **CRAN** (`medfit` 0.3.2,
  `RMediation` 1.6.1). `DESCRIPTION` no longer carries `Remotes:` or
  `Additional_repositories:`; missingmed itself is still served by the
  Data-Wise r-universe.

# missingmed 0.3.1

## Bug fixes

* **MBCO's constrained models did not null the whole path.** The constraint was
  imposed with `update(. ~ . - M)`, which removes only the term labeled exactly
  `M`; every other term carrying the mediator survived. `Y ~ X * M + C` kept
  `X:M`, and `Y ~ poly(M, 2) + X` was left **completely unchanged** -- so the
  "constrained" model equaled the full model, the statistic was exactly 0, and
  the test could never reject, at any sample size, with no error or warning.
  The constraint now drops every term whose variables include the target, which
  covers `poly(M, 2)`, `I(M^2)`, `log(M)`, splines and interactions alike.

  The effect was **conservative** -- an inflated constrained log-likelihood
  makes the statistic too small, so the test lost power. It did not produce
  false positives.

  Results for the plain `Y ~ X + M + C` / `M ~ X + C` specification are
  **unchanged to the digit**, so no previously reported analysis of that shape
  is affected.

* **MBCO's constrained models kept the response transformation, the intercept
  and any offset.** The constrained formula was rebuilt from term labels alone,
  which silently turned `log(Y) ~ .` into `Y ~ .` -- so the full and constrained
  log-likelihoods were computed on different scales and `2 * (llF - llC)` was
  not a likelihood ratio at all. On simulated data it produced `T = 813.76`,
  `p = 1.3e-32`, rejecting regardless of whether mediation existed; with the
  scale reversed it went negative and never rejected. A suppressed intercept
  (`Y ~ 0 + X + M`) was silently regained and `offset()` terms were dropped.
  Constrained models are now built with `stats::drop.terms()`, which carries all
  three through.

* **The MBCO statistic is now referred to the right degrees of freedom.** `k`
  was hard-coded to 1, which was correct only while the constraint removed a
  single parameter. Since the constraint now nulls the whole path, an
  interaction or a nonlinear term removes more, and the statistic was being
  referred to `F(1, nu)` regardless. `k` is now the number of parameters the
  winning branch actually removes. Pooling refuses, rather than guessing, when
  imputations disagree about that number -- the branch is data-dependent, and
  D4 assumes one `k`.

* `infer(type = "mbco")` on a single imputation returned a vector of `NaN`
  rather than an error. D4 pooling needs `m >= 2`; it now says so.

* `summary()` of a sensitivity curve no longer reports "no tipping point" when
  *every* rung tips. With a grid containing no MAR rung, that was false
  reassurance in exactly the direction a sensitivity analysis exists to prevent.

* `set_md_mediation(conf_level = NA)` failed with `missing value where
  TRUE/FALSE needed` instead of naming the argument -- the guard added to the
  fit and result classes had not been added to the entry-point class.

* **What MBCO's null means under a treatment-by-mediator interaction is now
  stated explicitly.** With that interaction the indirect effect is not `a * b`
  -- the natural indirect effect involves the interaction term too -- so the
  null needs a reading. `missingmed` takes the null to be **"the mediator has
  no effect on the outcome at all"**: the constrained outcome model drops the
  mediator's main effect *and* every interaction carrying it. The alternative
  (null the main effect only, leaving `X:M`) would let mediation run through
  the interaction under a hypothesis asserting there is none.

  Note that MBCO as published (Tofighi & Kelley, 2020) is stated for the
  no-interaction case; this is the package's stated extension of it, not a
  result from that paper. See
  `docs/specs/SPEC-mbco-constrained-models-2026-08-30.md`.

# missingmed 0.3.0

* New `sensitivity_mnar()` and `MDSensitivityResult`: MNAR sensitivity analysis
  by delta-adjusted imputation. Re-imputes across a grid of delta values and
  re-runs the pipeline at each rung, producing a sensitivity **curve** for the
  indirect effect. It is not an estimator -- MAR versus MNAR is not testable from
  observed data, so no rung is "the MNAR estimate".
* `sensitivity_mnar()` reports the **realized marginal sensitivity parameter**
  (`msp`) alongside the supplied `delta`. `delta` is a *conditional* sensitivity
  parameter; the quantity analysts can actually reason about is *marginal*, and
  supplying one for the other is the standard failure mode of this method
  (Tompsett et al. 2018). The two coincide only when a single variable is
  incomplete; with more, the shift feeds back through the chained equations.
* Documented refusals: IPW (no imputations to shift), categorical targets (the
  correct construction offsets the imputation model's linear predictor, with
  delta on the odds-ratio scale -- not yet implemented), and targets with no
  missing values.
* `set_md_mediation(mechanism = "mnar")` is **deprecated** and now warns. It
  never changed behavior -- `run()` estimates under MAR either way. `mechanism`
  is now derived: only `sensitivity_mnar()` sets it to `"mnar"`.
* Non-gaussian models (`family_y`, `family_m`) are now covered by tests and
  documented. GLM support was already plumbed -- `set_md_mediation()` forwards
  `engine`/`family_y`/`family_m` to `medfit::fit_mediation()`, whose default
  engine is `"glm"` -- but nothing exercised it. A binary mediator, a binary
  outcome and a count outcome are now tested through both estimators (`"mi"`
  and `"ipw"`) and through MBCO. No user-facing behavior changed.
* `vignette("technical")` gains a section on the **scale** of `a*b` under a
  non-identity link: the product is on the link scale (log-odds, log-rate), is
  not a risk difference or odds ratio, and `exp(a*b)` does not produce one. It
  also documents the benign `non-integer #successes` warning that
  `stats::glm()` emits for every IPW fit with a binomial family.

## Bug fixes

* **IPW weights could be silently misaligned to the wrong rows.** The
  observation probabilities came from `stats::fitted()`, which returns one value
  per row the missingness model *kept* -- so whenever a predictor of that model
  was itself incomplete (including the treatment, used for the stabilization
  numerator), the probability vector was shorter than the data, R recycled it,
  and the weights landed on the wrong rows. Estimates and sandwich standard
  errors were wrong, with only a `longer object length is not a multiple`
  warning. Probabilities now come from `predict(type = "response")`, which
  returns one value per row. A complete case whose weight is undefined is now an
  error naming the incomplete predictor, and a `weight_formula` list naming a
  variable that is not a column is refused up front.
* **`sensitivity_mnar()` re-imputed under a different model than the baseline.**
  The re-imputation replayed `method`, `predictorMatrix`, `visitSequence`,
  `where`, `blots` and `post`, but dropped `maxit`, `blocks`, `formulas` and
  `ignore`. Every rung therefore ran with mice's default 5 iterations, and the
  `delta = 0` rung reproduced the MAR analysis only when the baseline happened
  to use `maxit = 5`. The full specification is now replayed. A `mids` built
  with `maxit = 0` is refused: `post` only runs inside the sampler, so every
  rung would have been identical and the sensitivity curve silently flat.
* `sensitivity_mnar()` composed the delta into the `post` expression with
  `format()`, whose 7-significant-digit default silently truncated a delta such
  as `0.123456789`. It is now written at full precision.
* `sensitivity_mnar()` looked up the target's imputation method in
  `mids$method`, which is keyed by **block**, not by variable. A univariate
  block with a non-default name was wrongly rejected as multivariate, and a
  genuinely multivariate block named after one of its members was wrongly
  accepted. Block membership is now tested directly.
* **`pool()` masked `mice::pool()`.** The exported S7 generic had no method for
  anything but a missingmed fit, so after `library(missingmed)` the ordinary
  mice workflow `pool(with(imp, lm(...)))` failed with `Can't find method`.
  Non-missingmed objects are now forwarded to `mice::pool()`. Calling `pool()`
  on unfitted data or an already-pooled result reports the right next step.
* The `mice` dependency floor is raised to `>= 3.18.0`, the release that
  introduced `mids$calltype`. Below it the re-imputation could not tell a
  `formulas` baseline from a `predictorMatrix` one and would silently replay the
  wrong specification. A baseline mixing the two is now refused rather than
  collapsed.
* `VignetteBuilder` declared only `knitr` while the vignettes use the
  `knitr::rmarkdown` engine, so `R CMD check` under `_R_CHECK_DEPENDS_ONLY_`
  (CRAN's noSuggests pass) failed to rebuild them. `rmarkdown` is now declared.

* Raised the `RMediation` dependency floor to `>= 1.5.0`. That release replaced
  positional path-parameter resolution (which could silently assume `cov(a, b) = 0`)
  with strict name-based extraction. `pool()` already emits named estimates and a
  dimnamed vcov, so no user-visible behavior changes -- the floor makes the
  requirement explicit, and a new regression test pins it.

# missingmed 0.2.0

Major release: the package is rewritten from S4 to **S7** and gains a second
estimator (IPW). It is now a thin orchestration layer — fitting is delegated to
[medfit](https://data-wise.github.io/medfit/) and inference to
[RMediation](https://data-wise.github.io/rmediation/).

## New S7 pipeline

Four verbs over three S7 classes:

```
set_md_mediation()  ->  run()  ->  pool()  ->  infer()
   MDMediationData      MDMediationFit  MDMediationResult   CI / MBCO
```

* `set_md_mediation()` — entry point; records the data + a medfit-style mediation
  spec (outcome/mediator formulas + treatment/mediator roles).
* `run()` — fits each imputation via `medfit::fit_mediation()`, yielding a list
  of **named** `medfit::MediationData`.
* `pool()` — Rubin's-rules pooling of the named (estimates, vcov) into a single
  **named** pooled `medfit::MediationData`, valid input to
  `RMediation::ci_mediation_data()`.
* `infer(type = c("mc", "mbco"))` — Monte-Carlo / distribution-of-the-product CI
  (`mc`), or **D4-stacked MBCO** likelihood-ratio test (`mbco`).
* `per_imputation_list()` — exposes the per-imputation fits for MBCO (which does
  **not** commute with Rubin's rules).

New S7 classes: `MDMediationData`, `MDMediationFit`, `MDMediationResult`.

## Estimators

* **Multiple imputation (`method = "mi"`)** — the default; pools `m` imputed-data
  fits with Rubin's rules.
* **Inverse-probability weighting (`method = "ipw"`)** — new. Reweights the
  complete cases by inverse missingness probability and fits once. Supports a
  joint complete-case weight model (default) or per-variable formulas, stabilized
  weights, quantile trimming, and HC sandwich SEs (`se_type = "sandwich"`).

## MBCO under multiple imputation

* `infer(type = "mbco")` implements **D4-stacked MBCO**, which respects the
  union-null geometry of `H0: ab = 0` (`a = 0` or `b = 0`) — exact-match parity
  with the research prototype. See `vignette("mbco-mi")`.

## Documentation

* New vignettes: `missingmed` (getting started), `mbco-mi`, and `technical`
  (design, ecosystem contracts, and methodology).
* pkgdown site at <https://data-wise.github.io/missingmed/>.

## Deprecations

* The S4 API (`set_sem()`, `run_sem()`, `pool_sem()`, and the `SemImputedData` /
  `SemResults` / `PooledSEMResults` classes) is **deprecated** in favor of the
  S7 pipeline above. The shims emit a `.Deprecated()` warning and will be removed
  in a future release.

## Dependencies

* New `Imports`: `S7`, `medfit` (>= 0.3.1), `RMediation` (>= 1.4.0). `medfit` and
  `RMediation` are available from the Data-Wise R-universe.

# missingmed 0.1.0

* Initial S4 implementation: SEM-based mediation across multiply imputed datasets
  (`mice` + `lavaan`/`OpenMx`) with Rubin's-rules pooling.
