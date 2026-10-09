# SPEC: an SEM engine for the S7 pipeline (`engine = "lavaan"`)

| | |
|---|---|
| **Status** | APPROVED DESIGN: Q1–Q4 grilled 2026-09-23; section 4 grilled 2026-10-07 ([GRILL-s7-sem-engine-section4-2026-10-07.md](GRILL-s7-sem-engine-section4-2026-10-07.md), G1–G7); not implemented |
| **Target** | v0.6.0, together with the removal of the S4 API and the `OpenMx` import (G5). v0.5.0 shipped without SEM. |
| **Scope source** | Data-Wise/missingmed#1: "MI + IPW estimators, SEM + GLM models, MAR + MNAR sensitivity" |
| **Affects** | `R/set_md_mediation.R`, `R/MDMediationData.R`, `R/run.R`, `R/pool.R` (`.pool_wald()`), `R/infer.R`, `R/mbco_mi.R`, NEWS, vignettes |

## 1. Why

SEM exists only in the deprecated S4 API (`set_sem()` and the rest).
`medfit::fit_mediation()` accepts only `engine = "glm"` (checked, medfit 0.3.2);
medfit 0.4.0 adds `"regmedint"` (checked 2026-10-07), which is not an SEM
engine either. Removing the S4 code today would therefore remove SEM from the
package and break the scope in #1.
The S4 code is also the only reason missingmed imports `lavaan` and `OpenMx`.

## 2. What medfit already provides (checked 2026-09-23, medfit 0.3.2, lavaan)

`medfit::extract_mediation(<lavaan fit>, treatment, mediator)` returns a plain
`medfit::MediationData`. For `M ~ a*X + C; Y ~ b*M + cp*X + C`, n = 300:

| | lavaan fit | glm fit |
|---|---|---|
| `@estimates` names | `a, M~C, b, cp, Y~C, M~~M, Y~~Y, c_prime` (the unlabeled form gives `M~X, ...`) | `m_(Intercept), m_X, m_C, y_(Intercept), y_X, y_M, y_C, a, b, c_prime` |
| `a` | 0.44880 | 0.44880 |
| se(a) | 0.06518 (ML, divisor n) | 0.06550 (OLS, divisor n − p) |
| `n_obs`, `family_m`, `source_package` | 300, gaussian, `"lavaan"` | 300, gaussian, `"stats"` |

`pool()` and `infer(type = "mc")` therefore work unchanged. Three things do not:

- `.pool_wald()`'s `m_`/`y_` prefix rule for `dfcom`;
- `~~` rows receiving Wald tests;
- MBCO's `glm()` refit.

## 3. Decisions

| # | Question | Decision | Rejected |
|---|---|---|---|
| Q1 | API | `set_md_mediation(data, model = <lavaan syntax>, treatment, mediator, outcome, engine = "lavaan")` (`outcome` required for lavaan, G3). `model` replaces `formula_y`/`formula_m`, which must be NULL. `...` goes to `lavaan::sem()` (e.g. `estimator = "MLR"`). **lavaan only**: OpenMx support ends when the S4 API is removed. | translating formulas into lavaan syntax (observed variables only, so little gain over glm); a separate `set_md_sem()` |
| Q2 | Naming | **Keep lavaan's parameter names** (`M~C`, `Y~~Y`, user labels) and always carry the `a`/`b`/`c_prime` aliases. `.pool_wald()` becomes engine-aware: `dfcom = Inf` for lavaan, matching lavaan's z-tests. | renaming to `m_*`/`y_*` (undefined for latent or multi-equation models); pooling only a/b/c_prime |
| Q3 | `~~` rows | **Keep** them with the pooled estimate and SE; for a **variance** (`M~~M`) set `statistic` and `p_value` to **NA** and document the boundary null (variance = 0). A **covariance** between two different variables (`Y~~Y2`) has an interior null, so its z-test is kept (amended 2026-10-08 after an adversarial review of 0.6.0) | dropping them; computing boundary-null Wald tests |
| Q4 | MBCO | `infer(type = "mbco")` on a lavaan fit **errors** with a clear message in v0.6.0. MBCO for SEM gets its own spec: constrained refits with `lavaan::sem(constraints = "a == 0")`, the author's ruling on what "b = 0" means with a latent mediator, and a lavaan parity test. | building it in the same release as the lavaan engine; a glm refit for observed-only SEMs |

## 4. Section 4 decisions (grilled 2026-10-07)

Full reasoning and rejected options: [GRILL-s7-sem-engine-section4-2026-10-07.md](GRILL-s7-sem-engine-section4-2026-10-07.md).

| # | Question | Decision |
|---|---|---|
| G1 | IPW with lavaan | **Allowed**: `lavaan::sem(sampling.weights =)` on the complete cases, with `se = "robust.huber.white"` forced; a non-robust `se`/estimator in `...` errors. (Probe: same point estimates as the glm IPW path, SEs within the n vs n − p divisor; both treat the weights as known.) |
| G2 | Converged but improper solutions | **Warn once**, naming the imputations (`lavInspect(fit, "post.check")`); pooling proceeds. Non-convergence **refuses**, naming the imputations (glm path unchanged). |
| G3 | Outcome identity | **`outcome` required** for `engine = "lavaan"`, validated before fitting and passed to `extract_mediation()` (medfit otherwise takes the first variable regressed on the mediator). |
| G4 | `sensitivity_mnar()` | `type = "mc"` works (test); `type = "mbco"` inherits Q4's refusal. With a **latent** mediator, `target = NULL` errors and lists the indicators; an explicit observed `target` works. |
| — | Validation | `lavaan::lavaanify()` before any fitting: treatment, mediator and outcome appear; `mediator ~ treatment` and `outcome ~ mediator` exist (the mediator may be latent). |
| G5 | Release | Lavaan engine **and** S4 removal (dropping `OpenMx`) in **0.6.0**. |
| G6 | Engine | **lavaan only** (Q1 stands); an OpenMx engine is later work, starting with an OpenMx extractor in medfit. |
| G7 | S4 removal | `.Defunct()` stubs naming each replacement in 0.6.0; stubs deleted in 0.7.0. |

### Proposed amendment P3 (open; from the 2026-10-07 interface review)

**Status: partly accepted (2026-10-08, H1 of [GRILL-s7-sem-engine-plan-2026-10-08.md](GRILL-s7-sem-engine-plan-2026-10-08.md)).** `fit_args` is accepted for the lavaan engine in 0.6.0; the `run(...)` deprecation, glm `fit_args` and optional `outcome` on glm move to 0.7.0. Q1 and G1–G7 are not changed by this
subsection. The review compared missingmed's interface with medfit `med()`,
CMAverse, regmedint and bmlm (name-based roles) and lavaan.mi (lists of imputed
data).

**Two argument paths exist today, and they disagree:**

- **Q1's set-time `...`** (planned for lavaan, not implemented): `...` on
  `set_md_mediation()` goes to `lavaan::sem()`. The current signature in
  `R/set_md_mediation.R` has no `...`.
- **The current `run(...)`**: forwarded to `medfit::fit_mediation()`, on the MI
  path (`R/run.R`) and the IPW path (`.ipw_run()`, `R/ipw_run.R`).
  `sensitivity_mnar()` forwards its own `...` to `run()`
  (`R/sensitivity_mnar.R`), so run-time options are not stored on the object and
  every sensitivity refit must be given them again.

**Proposal:**

| Part | Proposed rule |
|---|---|
| Roles | One role triple across engines: `treatment`, `mediator`, `outcome`. On glm, `outcome` is optional, taken from `formula_y`'s left-hand side, and validated against it if given. On lavaan it stays required (G3). |
| Engine options | `fit_args = list()` on `set_md_mediation()`, stored on the `MDMediationData` object. It replaces Q1's set-time `...` (if accepted, Q1's `...` becomes `fit_args`) and the current `run(...)`. |
| Precedence | `fit_args` is the only stored path. `run(...)` warns as deprecated for one cycle and errors if it repeats a name in `fit_args`. `sensitivity_mnar()` reads the stored `fit_args`; its `...` follows the same deprecation path. |
| G1 constraint | `fit_args` must not override G1: on the IPW + lavaan path, a non-robust `se` or an estimator without a sandwich in `fit_args` errors, exactly as G1 specifies for `...`. |

**Trade-offs:** one more argument and a deprecation cycle for `run(...)`, against
one place for engine options and `sensitivity_mnar()` refits that reproduce the
original fit without restating its options.

**Naming (decided 2026-10-07, author):** the stored list is `fit_args`, not
`engine_args`. medfit 0.4.0's `fit_mediation()` already has an argument called
`engine_args = list()` (absent in 0.3.2), so the same name on
`set_md_mediation()` would mean two different lists in one call chain.

**Sub-questions:**

- **Name collision with medfit (resolved by the rename).** `fit_args` holds
  arguments for `medfit::fit_mediation()` (or, on the lavaan path, for
  `lavaan::sem()`). medfit's own `engine_args` is then an ordinary entry,
  `fit_args = list(engine_args = list(...))`, with no special case. A literal
  `run(obj, engine_args = list(...))` is a `run(...)` argument like any other and
  follows the deprecation rule above.
- **medfit floor (open).** `fit_args` itself needs no newer medfit; only an
  entry that is a 0.4.0-only argument (such as `engine_args`) does. Raising
  `Imports: medfit (>= 0.3.1)` to `>= 0.4.0` is needed only if missingmed
  itself starts relying on such an argument.

## 5. Acceptance criteria

- [ ] An observed-variable path model gives the same pooled `a`, `b` and
      `c_prime` under `engine = "lavaan"` as under `"glm"` (to 1e-6), and SEs
      within the ML/OLS ratio sqrt((n − p)/n).
- [ ] A **latent** mediator model (e.g. `M =~ m1 + m2 + m3`) runs through
      `run() → pool() → infer("mc")`.
- [ ] For the lavaan engine, `df` is `Inf`, and the p-values are normal-theory
      z p-values, which match `lavaan::parameterEstimates()` at `m = 1`.
- [ ] `~~` rows have finite `estimate`/`std_error` and NA `statistic`/`p_value`.
- [ ] `infer(type = "mbco")` on a lavaan fit errors, naming the follow-up.
- [ ] `method = "ipw"` with `engine = "lavaan"` matches the glm IPW point
      estimates on an observed path model (to 1e-6), and a non-robust `se` in
      `...` errors.
- [ ] A model with two variables regressed on the mediator and no `outcome`
      errors before fitting; non-convergence errors naming the imputation; an
      improper solution warns once naming it.
- [ ] `sensitivity_mnar(type = "mc")` runs on a lavaan fit; a latent mediator
      with `target = NULL` errors listing its indicators.
- [ ] The removed S4 exports are `.Defunct()` stubs naming their replacement,
      and `OpenMx` is gone from `Imports`.
- [ ] Passing formulas with `engine = "lavaan"`, or `model` with `engine = "glm"`,
      errors before any fitting.
- [ ] `R CMD check --as-cran` 0/0/0, the suite is green with strictly more tests,
      and `_pkgdown.yml` is updated if any export changes.
