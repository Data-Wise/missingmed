# Changelog

## missingmed (development version)

### New features

- `infer(type = "mc")` supports models with a treatment-by-mediator
  interaction (`Y ~ X * M + ...`) through a new `treatment_level`
  argument ([\#20](https://github.com/Data-Wise/missingmed/issues/20)).
  The indirect effect there is `a * (b + theta3 * x)`, so the interval
  is for the treatment level `x` you choose (for a 0/1 treatment, `1` is
  the total and `0` the pure natural indirect effect); it is drawn from
  the pooled estimates and pooled covariance of `a`, `b` and `theta3`
  with
  [`RMediation::ci()`](https://data-wise.github.io/rmediation/reference/ci.html),
  and the result names the estimand in `Estimand`. `treatment_level` is
  required for such models and an error elsewhere.
  `sensitivity_mnar(type = "mc")` passes it through.

### Bug fixes

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  now validates the model before fitting; previously a `formula_m` whose
  LHS was not `mediator` returned a wrong indirect effect silently. It
  also refuses terms the pipeline cannot pool correctly: the treatment
  and mediator may enter only as main effects, plus one `X:M` term in
  `formula_y` (products such as `X:C` or `M:W`, transforms such as
  `I(X^2)` or `log(M)`, and offsets involving either are refused, with a
  pointer to
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
  for moderated models); an `X:M` term with a non-Gaussian or
  non-identity-link `family_y` or `family_m`; and a non-numeric
  treatment (factor, character or logical; recode to numeric).

- [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
  now refuses a `formula_m` whose response involves anything but the
  mediator (`log(M) ~ X` is still accepted), and a `formula_y` whose
  response is the mediator.

- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  no longer errors on models with an `X:M` term
  ([\#20](https://github.com/Data-Wise/missingmed/issues/20)). It set
  the pooled path coefficients one at a time, which broke the invariants
  of medfit’s `InteractionMediationData`; it now sets them together,
  pools the interaction coefficient with Rubin’s rules, and recomputes
  the four-way decomposition (`pie`, `int_med`, `nie`, …) from the
  pooled paths and one pooled reference profile: `int_ref` uses the
  pooled `theta3` and the mean of the per-imputation mediator reference
  values (which differ when a covariate is imputed), and imputations
  fitted at different `m_star` are refused. The pooled `theta3` and `b0`
  rows now take the degrees of freedom of their source rows (`y_X:M`,
  `m_(Intercept)`).

- [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) of a pooled `X:M`
  fit report the indirect effect at `x = 0` and `x = 1` instead of a
  single `a*b`, which is the `x = 0` value only.

- The S7 classes validate more of their input, turning silent wrong
  answers and obscure late crashes into clear errors at construction:
  `MDMediationData` refuses `treatment == mediator`, missing or empty
  roles, an `engine` that is not a single string, an IPW
  `weight_stabilize` that is not `TRUE`/`FALSE` (it used to fit
  unstabilized weights silently), an NA `weight_trim`, and an
  `n_imputations` that disagrees with the data; `MDMediationFit` and
  `MDMediationResult` refuse non-fit objects and an NA `m`;
  `MDSensitivityResult` refuses zero rungs, rungs whose shape does not
  match `type`, and a `level` outside (0, 1).
  [`print()`](https://rdrr.io/r/base/print.html) of a result with an
  empty table no longer errors, and
  [`summary()`](https://rdrr.io/r/base/summary.html) of a sensitivity
  curve with NA rungs lists them (new `na_rungs` element) and declines
  to name a tipping point.

- Engines are checked when the model is set up: `engine` must be one of
  the engines missingmed supports with the installed medfit (`"glm"`,
  plus `"regmedint"` with medfit \>= 0.4.0 and the MI estimator);
  anything else, including `"lavaan"` (planned for 0.6.0;
  [`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md)
  exists today), errors in
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  instead of inside
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md). A
  failed fit is reported as
  `engine "glm" failed on imputation i of m: ...`, keeping the original
  message, and fitting warnings are collected into one warning naming
  the imputations.

- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  aligns the per-imputation estimates and covariance matrices by name;
  imputations whose coefficients came in a different order were stacked
  by position and silently scrambled every pooled estimate. Imputations
  with different coefficient sets are refused, naming the terms, and a
  pooled `b` that is NA (an aliased mediator) gets a clear error.

- [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  warns when a mids leaves a model variable incomplete, since each
  imputation is then fitted on its complete cases. `Y ~ .` now works in
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md),
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md),
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
  and `infer(type = "mbco")`. A non-syntactic treatment or mediator name
  (for example `` `my M` ``), which medfit cannot fit, is refused at
  set-up.

- IPW: with no missing data the weights are exactly 1 without fitting a
  degenerate response model (no more non-convergence warnings); zero
  complete cases, a `weight_formula` that is not a formula or named list
  of formulas, uses `.`, or names absent variables, and an NA
  `weight_trim`, `weight_stabilize` or `conf_int` are refused at set-up.
  Names in a `weight_formula` now resolve in the formula’s environment.

- [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
  refuses a `level` outside (0, 1) (0 gave a zero-width interval), an
  `n.mc` below 2 or not a whole number, and unknown arguments in `...`
  (for example `conf.level = 0.9` was silently ignored and a 95%
  interval returned).

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  checks `seed` and `level` before re-imputing, and refuses a delta grid
  with duplicate or empty column names (a duplicate name silently
  reported the wrong rung) and a delta matrix with more than one column.
  `seed = NA` is refused because it made the curve irreproducible.

- [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
  and `infer(type = "mbco")` refuse imputations that differ in row
  count, columns, or a model variable’s type, and NA left in a model
  variable (which silently dropped different rows per model); a failed
  fit names its imputation. When the imputations are identical, `r4` is
  now exactly 0 and `nu` is `Inf` instead of rounding noise.

- The deprecated S4 pipeline works again:
  [`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md)
  failed on every call (an internal
  [`lav_mice()`](https://data-wise.github.io/missingmed/reference/lav_mice.md)/[`mx_mice()`](https://data-wise.github.io/missingmed/reference/mx_mice.md)
  with swapped arguments was masked by the exported functions), and
  [`lav_mice()`](https://data-wise.github.io/missingmed/reference/lav_mice.md)
  rejected every valid model syntax (an inverted check).
  [`fit_model()`](https://data-wise.github.io/missingmed/reference/fit_model.md)
  and
  [`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md)
  list the accepted model types for anything else; a lavaan or OpenMx
  failure names its imputation, and per-imputation warnings are
  collected into one.
  [`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)
  needs at least two imputations (with one, every standard error was
  NA),
  [`is_pd()`](https://data-wise.github.io/missingmed/reference/is_pd.md)
  returns `FALSE` for a non-symmetric matrix, `PooledSEMResults`
  requires its four base columns,
  [`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md)
  refuses a `conf_level` of 0 or 1, and
  [`mx_mice()`](https://data-wise.github.io/missingmed/reference/mx_mice.md)
  now passes `...` to
  [`OpenMx::mxRun()`](https://rdrr.io/pkg/OpenMx/man/mxRun.html) as
  documented (so unknown arguments error) and runs the imputations
  sequentially (`lapply`, not `omxLapply`).

- New tests: edge cases for every exported function, and end-to-end
  tests that check the pooled estimates, variances and degrees of
  freedom against
  [`mice::pool()`](https://amices.org/mice/reference/pool.html), and MC,
  MBCO, IPW and sensitivity results against known answers.

## missingmed 0.5.0

### New features

- **`infer(type = "mbco")` gains `ariv = c("fixed", "own")`, default
  `"fixed"`**
  ([\#19](https://github.com/Data-Wise/missingmed/issues/19)). `ariv`
  sets which per-imputation statistics enter the relative increase in
  variance `r4` of the D4-stacked MBCO test:

  - `"fixed"` recomputes every imputation’s statistic on the branch
    (`a = 0` or `b = 0`) that the stacked constrained fit chose. Every
    imputation then uses the stacked fit’s `k`, so models whose two
    paths carry different numbers of terms (an `X:M` interaction) now
    return a result. A guard errors when the branch’s constraint removes
    a different number of parameters in some imputation than in the
    stacked data (for example, a level of a factor that interacts with
    the treatment or mediator is absent from one imputation).
  - `"own"` uses each imputation’s own winning branch and **reproduces
    earlier results exactly on full-rank designs**; it still refuses
    when the branches remove different numbers of parameters.

  Code that relied on the old behavior should pass `ariv = "own"`. The
  default changes results only when some imputation’s own branch differs
  from the stacked fit’s. `sensitivity_mnar(type = "mbco")` calls
  [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
  and so uses the new default for its rungs. A single imputation (K = 1)
  is still an error, now pointing to complete-data MBCO.

- **New exported
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)**:
  the same test on a plain list of completed data frames, with
  `formula_y`, `formula_m`, families, `treatment`, `mediator` and
  `ariv`, so other packages can call it without `:::`.

- **New result class `MbcoMIResult`** (S7, parent `class_double`),
  returned by `infer(type = "mbco")` and
  [`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md).
  Its data is the same named numeric `c(D4, p, r4, nu, d_S)`; its
  properties are `ariv`, `k`, `m`, `stacked_branch`, `branch_mix` and
  `p_branch_a`. It has [`print()`](https://rdrr.io/r/base/print.html)
  and [`tidy()`](https://generics.r-lib.org/reference/tidy.html)
  methods. `r["p"]`, `r[["p"]]` and `is.numeric(r)` work as before, and
  `S7::S7_data(r)` returns the old vector. Two behavior changes:
  `identical(r, old_vector)` is now `FALSE`, and `r$p` errors (the old
  vector had no `$` either).

  Reporting `branch_mix` and `p_branch_a` needs both single-path null
  fits in every imputation; the `"fixed"` statistic alone would need
  only the stacked branch’s.

### Bug fixes

- The MBCO constraint’s `k` (the numerator df of the D4 test) is now a
  rank difference, `rank(full) - rank(null)`, under both `ariv` values,
  instead of a column count. Nothing changes on full-rank designs. On a
  design with aliased columns, such as a factor level absent from the
  data, 0.4.0 overcounted `k`, so `ariv = "own"` can now give a smaller
  `k` than 0.4.0 did there.

### Documentation

- [`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md)
  is retitled “Testing an indirect effect with incomplete data” and
  expanded into a worked guide.

## missingmed 0.4.0

### New features

- **[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)’s
  tidy table now carries a Rubin-pooled Wald test per coefficient**:
  `statistic`, `df`, `riv`, `fmi` and `p_value`. The `p_value` column
  was documented but never built. `df` is the Barnard–Rubin (1999)
  small-sample df with each model’s own complete-data df (infinite for
  binomial and poisson models). At `m = 1` (IPW) it is the ordinary
  single-fit Wald test, matching
  [`summary.glm()`](https://rdrr.io/r/stats/summary.glm.html). These
  test **one path at a time**, not the indirect effect; use
  [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
  for that. The S4
  [`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md)’s
  `p_value` meant something else, a geometric mean of per-imputation
  p-values.

- **[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  delegates to `mice`’s NARFCS methods** (Tompsett et al. 2018;
  Moreno-Betancur, van Buuren & White 2020). The route depends on the
  target’s imputation method:

  - `norm` goes through `mnar.norm` when given a `ums` string (below). A
    numeric `delta` on a `norm` target keeps the `post` shift – for a
    constant delta the two give identical draws (pinned by a regression
    test), so existing results do not change.
  - **A binary target imputed by `logreg` now runs** through
    `mnar.logreg`, with delta on the **log-odds** scale; it used to be
    refused. `delta = 0` reproduces the MAR analysis exactly, and `msp`
    is reported as a prevalence difference.
  - Every other method (`pmm`, `norm.nob`, `cart`, …) keeps the `post`
    shift. Only an exact `norm`/`logreg` match is delegated: swapping
    `norm.boot` or `logreg.boot` would change the imputation method, so
    `delta = 0` would stop reproducing MAR. `logreg.boot`, `polyreg`,
    `polr` and `lda` targets are refused.

- New `ums` argument: a **covariate-varying** delta for a delegated
  target, one rung per string (e.g. `"1 + 0.5*C"`), passed verbatim to
  NARFCS. Every string is checked with a one-iteration probe before any
  rung runs: a string mice cannot parse, or one that yields NA
  imputations (a typo’d coefficient only makes mice warn), is refused
  and named. [`summary()`](https://rdrr.io/r/base/summary.html) does not
  compute a tipping point for a `ums` grid, because it has no numeric
  ordering.

- `MDSensitivityResult` gains `@mechanism_used` and `@scale`, one entry
  per target. [`print()`](https://rdrr.io/r/base/print.html) and
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) show them.

### Bug fixes

- **[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  refuses a rung whose imputations are not finite.** If a delta or `ums`
  made the imputation chain produce NA, NaN or Inf, the fit dropped
  those rows and reported a complete-case result as the rung. The
  up-front `ums` check runs one iteration and cannot see failures that
  start later, so every rung is now checked after it is re-imputed.

- **A numeric 0/1 target is no longer shifted additively.** `mice`
  imputes a numeric 0/1 column with `pmm` by default, so
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  added the delta to drawn 0/1 values: a gaussian mediator model then
  silently analyzed imputed 1s and 2s, and a binomial one failed late
  inside `glm`. A 0/1 target whose imputations are themselves all 0/1
  (`pmm`, `cart`, `sample`, …) is now refused unless it is imputed by
  `logreg`, which routes it to `mnar.logreg`. The rule reads the imputed
  values, not a list of methods: a normal-model (`norm*`) imputation of
  a 0/1 variable is continuous and is still allowed, with `delta` or
  `ums` alike. **Analyses that ran before now error**; that is the
  intent.

- **A non-finite `delta` is refused.** `delta = c(0, NA)` used to run,
  with that rung’s imputations all NA; NA, NaN and Inf are now errors,
  as is a non-numeric column in a data-frame grid.

- **A target named like a
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) column is
  refused.** A target named `msp` (or `estimate`, `conf_low`,
  `conf_high`, `D4`, `p_value`, `mechanism`, `scale`) had its delta
  column silently overwritten in
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html).

- **[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)’s
  categorical guard looked up the imputation method by variable name.**
  `mids$method` is keyed by block, so a 0/1 target imputed by `logreg`
  in a block with a non-default name slipped past the guard and got an
  additive shift on its drawn 0/1 values. The method is now resolved
  through the target’s block, as the rest of the function already did.

- **The default IPW path failed without `sandwich` installed.**
  `method = "ipw"` defaults to `se_type = "sandwich"`, which `medfit`
  computes with
  [`sandwich::vcovHC()`](https://zeileis.codeberg.page/sandwich/reference/vcovHC.html)
  – but `sandwich` is only a Suggests of `medfit` and was not declared
  by missingmed at all, so
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  errored on a machine without it. `sandwich` is now in Imports.

- **`R CMD check` now runs the test suite.** `tests/testthat.R` never
  existed, so neither `R CMD check` nor CI had ever run
  `tests/testthat/`; adding it is what surfaced the `sandwich` bug
  above.

### Dependencies

- `medfit` and `RMediation` now install from **CRAN** (`medfit` 0.3.2,
  `RMediation` 1.6.1). `DESCRIPTION` no longer carries `Remotes:` or
  `Additional_repositories:`; missingmed itself is still served by the
  Data-Wise r-universe.

## missingmed 0.3.1

### Bug fixes

- **MBCO’s constrained models did not null the whole path.** The
  constraint was imposed with `update(. ~ . - M)`, which removes only
  the term labelled exactly `M`; every other term carrying the mediator
  survived. `Y ~ X * M + C` kept `X:M`, and `Y ~ poly(M, 2) + X` was
  left **completely unchanged** – so the “constrained” model equalled
  the full model, the statistic was exactly 0, and the test could never
  reject, at any sample size, with no error or warning. The constraint
  now drops every term whose variables include the target, which covers
  `poly(M, 2)`, `I(M^2)`, `log(M)`, splines and interactions alike.

  The effect was **conservative** – an inflated constrained
  log-likelihood makes the statistic too small, so the test lost power.
  It did not produce false positives.

  Results for the plain `Y ~ X + M + C` / `M ~ X + C` specification are
  **unchanged to the digit**, so no previously reported analysis of that
  shape is affected.

- **MBCO’s constrained models kept the response transformation, the
  intercept and any offset.** The constrained formula was rebuilt from
  term labels alone, which silently turned `log(Y) ~ .` into `Y ~ .` –
  so the full and constrained log-likelihoods were computed on different
  scales and `2 * (llF - llC)` was not a likelihood ratio at all. On
  simulated data it produced `T = 813.76`, `p = 1.3e-32`, rejecting
  regardless of whether mediation existed; with the scale reversed it
  went negative and never rejected. A suppressed intercept
  (`Y ~ 0 + X + M`) was silently regained and
  [`offset()`](https://rdrr.io/r/stats/offset.html) terms were dropped.
  Constrained models are now built with
  [`stats::drop.terms()`](https://rdrr.io/r/stats/delete.response.html),
  which carries all three through.

- **The MBCO statistic is now referred to the right degrees of
  freedom.** `k` was hard-coded to 1, which was correct only while the
  constraint removed a single parameter. Since the constraint now nulls
  the whole path, an interaction or a nonlinear term removes more, and
  the statistic was being referred to `F(1, nu)` regardless. `k` is now
  the number of parameters the winning branch actually removes. Pooling
  refuses, rather than guessing, when imputations disagree about that
  number – the branch is data-dependent, and D4 assumes one `k`.

- `infer(type = "mbco")` on a single imputation returned a vector of
  `NaN` rather than an error. D4 pooling needs `m >= 2`; it now says so.

- [`summary()`](https://rdrr.io/r/base/summary.html) of a sensitivity
  curve no longer reports “no tipping point” when *every* rung tips.
  With a grid containing no MAR rung, that was false reassurance in
  exactly the direction a sensitivity analysis exists to prevent.

- `set_md_mediation(conf_level = NA)` failed with
  `missing value where TRUE/FALSE needed` instead of naming the argument
  – the guard added to the fit and result classes had not been added to
  the entry-point class.

- **What MBCO’s null means under a treatment-by-mediator interaction is
  now stated explicitly.** With that interaction the indirect effect is
  not `a * b` – the natural indirect effect involves the interaction
  term too – so the null needs a reading. `missingmed` takes the null to
  be **“the mediator has no effect on the outcome at all”**: the
  constrained outcome model drops the mediator’s main effect *and* every
  interaction carrying it. The alternative (null the main effect only,
  leaving `X:M`) would let mediation run through the interaction under a
  hypothesis asserting there is none.

  Note that MBCO as published (Tofighi & Kelley, 2020) is stated for the
  no-interaction case; this is the package’s stated extension of it, not
  a result from that paper. See
  `docs/specs/SPEC-mbco-constrained-models-2026-08-30.md`.

## missingmed 0.3.0

- New
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  and `MDSensitivityResult`: MNAR sensitivity analysis by delta-adjusted
  imputation. Re-imputes across a grid of delta values and re-runs the
  pipeline at each rung, producing a sensitivity **curve** for the
  indirect effect. It is not an estimator – MAR versus MNAR is not
  testable from observed data, so no rung is “the MNAR estimate”.
- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  reports the **realized marginal sensitivity parameter** (`msp`)
  alongside the supplied `delta`. `delta` is a *conditional* sensitivity
  parameter; the quantity analysts can actually reason about is
  *marginal*, and supplying one for the other is the standard failure
  mode of this method (Tompsett et al. 2018). The two coincide only when
  a single variable is incomplete; with more, the shift feeds back
  through the chained equations.
- Documented refusals: IPW (no imputations to shift), categorical
  targets (the correct construction offsets the imputation model’s
  linear predictor, with delta on the odds-ratio scale – not yet
  implemented), and targets with no missing values.
- `set_md_mediation(mechanism = "mnar")` is **deprecated** and now
  warns. It never changed behavior –
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  estimates under MAR either way. `mechanism` is now derived: only
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  sets it to `"mnar"`.
- Non-gaussian models (`family_y`, `family_m`) are now covered by tests
  and documented. GLM support was already plumbed –
  [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  forwards `engine`/`family_y`/`family_m` to
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
  whose default engine is `"glm"` – but nothing exercised it. A binary
  mediator, a binary outcome and a count outcome are now tested through
  both estimators (`"mi"` and `"ipw"`) and through MBCO. No user-facing
  behavior changed.
- [`vignette("technical")`](https://data-wise.github.io/missingmed/articles/technical.md)
  gains a section on the **scale** of `a*b` under a non-identity link:
  the product is on the link scale (log-odds, log-rate), is not a risk
  difference or odds ratio, and `exp(a*b)` does not produce one. It also
  documents the benign `non-integer #successes` warning that
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html) emits for every IPW
  fit with a binomial family.

### Bug fixes

- **IPW weights could be silently misaligned to the wrong rows.** The
  observation probabilities came from
  [`stats::fitted()`](https://rdrr.io/r/stats/fitted.values.html), which
  returns one value per row the missingness model *kept* – so whenever a
  predictor of that model was itself incomplete (including the
  treatment, used for the stabilization numerator), the probability
  vector was shorter than the data, R recycled it, and the weights
  landed on the wrong rows. Estimates and sandwich standard errors were
  wrong, with only a `longer object length is not a multiple` warning.
  Probabilities now come from `predict(type = "response")`, which
  returns one value per row. A complete case whose weight is undefined
  is now an error naming the incomplete predictor, and a
  `weight_formula` list naming a variable that is not a column is
  refused up front.

- **[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  re-imputed under a different model than the baseline.** The
  re-imputation replayed `method`, `predictorMatrix`, `visitSequence`,
  `where`, `blots` and `post`, but dropped `maxit`, `blocks`, `formulas`
  and `ignore`. Every rung therefore ran with mice’s default 5
  iterations, and the `delta = 0` rung reproduced the MAR analysis only
  when the baseline happened to use `maxit = 5`. The full specification
  is now replayed. A `mids` built with `maxit = 0` is refused: `post`
  only runs inside the sampler, so every rung would have been identical
  and the sensitivity curve silently flat.

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  composed the delta into the `post` expression with
  [`format()`](https://rdrr.io/r/base/format.html), whose
  7-significant-digit default silently truncated a delta such as
  `0.123456789`. It is now written at full precision.

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  looked up the target’s imputation method in `mids$method`, which is
  keyed by **block**, not by variable. A univariate block with a
  non-default name was wrongly rejected as multivariate, and a genuinely
  multivariate block named after one of its members was wrongly
  accepted. Block membership is now tested directly.

- **[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  masked
  [`mice::pool()`](https://amices.org/mice/reference/pool.html).** The
  exported S7 generic had no method for anything but a missingmed fit,
  so after
  [`library(missingmed)`](https://github.com/Data-Wise/missingmed) the
  ordinary mice workflow `pool(with(imp, lm(...)))` failed with
  `Can't find method`. Non-missingmed objects are now forwarded to
  [`mice::pool()`](https://amices.org/mice/reference/pool.html). Calling
  [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  on unfitted data or an already-pooled result reports the right next
  step.

- The `mice` dependency floor is raised to `>= 3.18.0`, the release that
  introduced `mids$calltype`. Below it the re-imputation could not tell
  a `formulas` baseline from a `predictorMatrix` one and would silently
  replay the wrong specification. A baseline mixing the two is now
  refused rather than collapsed.

- `VignetteBuilder` declared only `knitr` while the vignettes use the
  `knitr::rmarkdown` engine, so `R CMD check` under
  `_R_CHECK_DEPENDS_ONLY_` (CRAN’s noSuggests pass) failed to rebuild
  them. `rmarkdown` is now declared.

- Raised the `RMediation` dependency floor to `>= 1.5.0`. That release
  replaced positional path-parameter resolution (which could silently
  assume `cov(a, b) = 0`) with strict name-based extraction.
  [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
  already emits named estimates and a dimnamed vcov, so no user-visible
  behavior changes – the floor makes the requirement explicit, and a new
  regression test pins it.

## missingmed 0.2.0

Major release: the package is rewritten from S4 to **S7** and gains a
second estimator (IPW). It is now a thin orchestration layer — fitting
is delegated to [medfit](https://data-wise.github.io/medfit/) and
inference to [RMediation](https://data-wise.github.io/rmediation/).

### New S7 pipeline

Four verbs over three S7 classes:

    set_md_mediation()  ->  run()  ->  pool()  ->  infer()
       MDMediationData      MDMediationFit  MDMediationResult   CI / MBCO

- [`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
  — entry point; records the data + a medfit-style mediation spec
  (outcome/mediator formulas + treatment/mediator roles).
- [`run()`](https://data-wise.github.io/missingmed/reference/run.md) —
  fits each imputation via
  [`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
  yielding a list of **named**
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html).
- [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) —
  Rubin’s-rules pooling of the named (estimates, vcov) into a single
  **named** pooled
  [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html),
  valid input to
  [`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html).
- `infer(type = c("mc", "mbco"))` — Monte-Carlo /
  distribution-of-the-product CI (`mc`), or **D4-stacked MBCO**
  likelihood-ratio test (`mbco`).
- [`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)
  — exposes the per-imputation fits for MBCO (which does **not** commute
  with Rubin’s rules).

New S7 classes: `MDMediationData`, `MDMediationFit`,
`MDMediationResult`.

### Estimators

- **Multiple imputation (`method = "mi"`)** — the default; pools `m`
  imputed-data fits with Rubin’s rules.
- **Inverse-probability weighting (`method = "ipw"`)** — new. Reweights
  the complete cases by inverse missingness probability and fits once.
  Supports a joint complete-case weight model (default) or per-variable
  formulas, stabilized weights, quantile trimming, and HC sandwich SEs
  (`se_type = "sandwich"`).

### MBCO under multiple imputation

- `infer(type = "mbco")` implements **D4-stacked MBCO**, which respects
  the union-null geometry of `H0: ab = 0` (`a = 0` or `b = 0`) —
  exact-match parity with the research prototype. See
  [`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

### Documentation

- New vignettes: `missingmed` (getting started), `mbco-mi`, and
  `technical` (design, ecosystem contracts, and methodology).
- pkgdown site at <https://data-wise.github.io/missingmed/>.

### Deprecations

- The S4 API
  ([`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md),
  [`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md),
  [`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md),
  and the `SemImputedData` / `SemResults` / `PooledSEMResults` classes)
  is **deprecated** in favor of the S7 pipeline above. The shims emit a
  [`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) warning and
  will be removed in a future release.

### Dependencies

- New `Imports`: `S7`, `medfit` (\>= 0.3.1), `RMediation` (\>= 1.4.0).
  `medfit` and `RMediation` are available from the Data-Wise R-universe.

## missingmed 0.1.0

- Initial S4 implementation: SEM-based mediation across multiply imputed
  datasets (`mice` + `lavaan`/`OpenMx`) with Rubin’s-rules pooling.
