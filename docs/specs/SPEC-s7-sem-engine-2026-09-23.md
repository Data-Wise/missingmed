# SPEC: an SEM engine for the S7 pipeline (`engine = "lavaan"`)

| | |
|---|---|
| **Status** | APPROVED DESIGN: Q1–Q4 grilled 2026-09-23; section 4 grilled 2026-10-07 ([GRILL-s7-sem-engine-section4-2026-10-07.md](GRILL-s7-sem-engine-section4-2026-10-07.md), G1–G7); not implemented |
| **Target** | v0.6.0, together with the removal of the S4 API and the `OpenMx` import (G5). v0.5.0 shipped without SEM. |
| **Scope source** | Data-Wise/missingmed#1: "MI + IPW estimators, SEM + GLM models, MAR + MNAR sensitivity" |
| **Affects** | `R/set_md_mediation.R`, `R/MDMediationData.R`, `R/run.R`, `R/pool.R` (`.pool_wald()`), `R/infer.R`, `R/mbco_mi.R`, NEWS, vignettes |

## 1. Why

SEM exists only in the deprecated S4 API (`set_sem()` and the rest).
`medfit::fit_mediation()` accepts only `engine = "glm"` (checked, medfit 0.3.2), so
removing the S4 code today would remove SEM from the package and break the scope in #1.
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
| Q3 | `~~` rows | **Keep** them with the pooled estimate and SE; set `statistic` and `p_value` to **NA** and document the boundary null (variance = 0) | dropping them; computing boundary-null Wald tests |
| Q4 | MBCO | `infer(type = "mbco")` on a lavaan fit **errors** with a clear message in v0.5.0. MBCO for SEM gets its own spec: constrained refits with `lavaan::sem(constraints = "a == 0")`, the author's ruling on what "b = 0" means with a latent mediator, and a lavaan parity test. | building it in v0.5.0; a glm refit for observed-only SEMs |

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
