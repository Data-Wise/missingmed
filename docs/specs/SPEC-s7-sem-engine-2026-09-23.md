# SPEC: an SEM engine for the S7 pipeline (`engine = "lavaan"`)

| | |
|---|---|
| **Status** | APPROVED DESIGN: decisions grilled 2026-09-23 (Q1–Q4); not implemented, and section 4 is still open |
| **Target** | v0.5.0. This unblocks removing the S4 API in v0.6.0, and with it `OpenMx`. |
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
| Q1 | API | `set_md_mediation(data, model = <lavaan syntax>, treatment, mediator, engine = "lavaan")`. `model` replaces `formula_y`/`formula_m`, which must be NULL. `...` goes to `lavaan::sem()` (e.g. `estimator = "MLR"`). **lavaan only**: OpenMx support ends when the S4 API is removed. | translating formulas into lavaan syntax (observed variables only, so little gain over glm); a separate `set_md_sem()` |
| Q2 | Naming | **Keep lavaan's parameter names** (`M~C`, `Y~~Y`, user labels) and always carry the `a`/`b`/`c_prime` aliases. `.pool_wald()` becomes engine-aware: `dfcom = Inf` for lavaan, matching lavaan's z-tests. | renaming to `m_*`/`y_*` (undefined for latent or multi-equation models); pooling only a/b/c_prime |
| Q3 | `~~` rows | **Keep** them with the pooled estimate and SE; set `statistic` and `p_value` to **NA** and document the boundary null (variance = 0) | dropping them; computing boundary-null Wald tests |
| Q4 | MBCO | `infer(type = "mbco")` on a lavaan fit **errors** with a clear message in v0.5.0. MBCO for SEM gets its own spec: constrained refits with `lavaan::sem(constraints = "a == 0")`, the author's ruling on what "b = 0" means with a latent mediator, and a lavaan parity test. | building it in v0.5.0; a glm refit for observed-only SEMs |

## 4. Open questions (not grilled; decide during implementation, or in a follow-up grill)

- **IPW with lavaan.** `sampling.weights =` exists in lavaan, but the IPW path's
  `se_type = "sandwich"` is a medfit/glm feature. Proposed: refuse
  `method = "ipw"` with `engine = "lavaan"` in v0.5.0.
- **`sensitivity_mnar()` with lavaan.** It calls `run()` per rung, so the `mc`
  type should work unchanged, and `type = "mbco"` inherits Q4's refusal. Needs
  a test.
- **Validation.** `treatment` and `mediator` must appear in the lavaan model;
  check with `lavaan::lavaanify()` before any fitting.
- **Convergence.** A lavaan fit that fails to converge in one imputation needs
  the same `@converged` handling as glm. Decide: warn, or refuse.

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
- [ ] Passing formulas with `engine = "lavaan"`, or `model` with `engine = "glm"`,
      errors before any fitting.
- [ ] `R CMD check --as-cran` 0/0/0, the suite is green with strictly more tests,
      and `_pkgdown.yml` is updated if any export changes.
