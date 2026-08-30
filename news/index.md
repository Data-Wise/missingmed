# Changelog

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
  the union-null geometry of `H0: ab = 0` (branch switching) —
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
