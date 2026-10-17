# SPEC: lavaan MBCO on medfit's `mbco_sem()` (replaces the lavaan provider)

| | |
|---|---|
| **Status** | DRAFT for approval. No code written. |
| **Date** | 2026-10-16 |
| **Supersedes** | `NOTE-lavaan-mbco-delegation-2026-10-16.md` (which recommended not delegating; the author reversed it the same day and chose **replace**, not opt-in) |
| **Affects** | `R/mbco_lavaan.R` (replaced), `R/infer.R`, `R/mbco_mi.R`, `DESCRIPTION`, 5 test files, `dev/sim-sem-mbco-mlr-*.R`, vignettes, NEWS |

## 1. Parity evidence (run 2026-10-16, medfit 0.10.0 from `origin/main` in a scratch library, lavaan 0.7.3)

`mbco_sem()$tests$diff_ll` against `2 * (ll_full - ll_null)` from missingmed's lavaan provider construction:

| Model | a branch | b branch | max abs difference |
|---|---|---|---|
| observed, n = 300 | 43.08153 | 30.58981 | 2.4e-13 |
| latent mediator (3 indicators), n = 400 | 50.37483 | 31.7686 | 6.5e-12 |
| interior null `b = 0`, n = 300 (branches disagree) | 69.39514 | 0.0808688 | 3.6e-13 |

So the statistic is the same; the D4 pooling uses only differences of log-likelihoods
(`R/mbco_mi.R:127`, `:332`), so the T8a calibration carries over unchanged. A provider is
`full = 0`, `a = -diff_a / 2`, `b = -diff_b / 2`, `k_a = k_b = 1`.

## 2. What the replacement costs (found while scoping; each needs a ruling)

| # | Today (lavaan provider) | With `mbco_sem()` | Proposed ruling |
|---|---|---|---|
| C1 | a and b rows found as `M ~ X`, `Y ~ M` in any lavaan syntax | `mbco_sem()` needs **labeled** paths (unlabeled gives "not a labeled regression path") | Provider injects labels into the `M ~ ... X` and `Y ~ ... M` terms (or reuses the user's label); refuse syntax it cannot rewrite unambiguously, naming the line |
| C2 | `fit_args` go to `lavaan::sem()` (`fixed.x`, `likelihood`, `conditional.x`, `std.lv`, ...) and reach the null refits | `fit_sem()` takes only `information`, `n_starts`, `control`, `meanstructure`, `fixed_x` | Allow `estimator = "ML"`, `std.lv`/`auto.*` (no likelihood effect, ignored), `fixed.x` (mapped), `information`, `control` (mapped); **refuse** the rest, naming the option. A refused option that `run()` accepts is a **breaking change** for `infer(type = "mbco")` only |
| C3 | `:=` defined parameters and label equalities are supported | medfit supports labels and `==` constraints; `:=` rows must be checked | Port the two tests (`:=`, equality) as parity oracles; refuse what medfit rejects |
| C4 | MLR scaled-difference code (`.mm_lav_cd()`, `scaling`, `internal_mlr`) kept for a gate harness | none | **Delete** it, the `dev/sim-sem-mbco-mlr-*.R` harness and `test-mbco-mlr.R`; the failed gate stays on record in SPEC-sem-mbco section 12 and PR #84 |
| C5 | lavaan non-convergence and `post.check` (improper solution) messages | `SEMFit@converged`; `diagnostics$improper` | Map both; keep the "warns once, naming the datasets" behavior |
| C6 | `lavaan (>= 0.7-3)` in Imports for MBCO | `medfit (>= 0.10.0)` hard Import; lavaan still needed for `run()` | `DESCRIPTION`: raise the medfit floor. **CRAN is blocked until medfit 0.10.0 is on CRAN** (CRAN has 0.3.2; its own `mbco_sem()` arrives with it). No `Remotes:` unless needed for r-universe |
| C7 | `run()` fits with `lavaan::sem()`; MBCO fits with the same | `run()` still lavaan; MBCO now fits with `fit_sem()` | Same likelihood on the supported option set (section 1). Document that MBCO no longer uses lavaan's optimizer, and keep a parity test as the guard |

## 3. Design

- New `R/mbco_sem.R`: `.mm_sem_provider(model, treatment, mediator, outcome, fit_args)` returns
  `function(d)` giving `c(full = 0, a = , b = , k_a = 1, k_b = 1)` with `attr(, "improper")`.
  `.mm_d4_pool()` is unchanged.
- `.mm_sem_label_model(model, treatment, mediator, outcome)` returns the syntax with the two
  paths labeled plus the two labels. Reuses an existing label; refuses a fixed value (`M ~ 0.5*X`),
  a path appearing twice, a multi-group model.
- `.mm_lav_check_args()` becomes `.mm_sem_check_args()` with the C2 allow-list and the existing
  refusals (`ordered`, `group`, `sampling.weights`, non-ML estimator).
- `R/mbco_lavaan.R`, the MLR hooks in `.mm_d4_pool()` (lines ~360-392) and `test-mbco-mlr.R` are removed.

## 4. Tests (each can fail)

1. **Parity oracle** (`skip_if_not_installed("medfit", "0.10.0")`): the three models in section 1,
   `diff_ll` vs the 0* lavaan oracle to 1e-9. Planted defect: swap labels `a`/`b` and confirm red.
2. Port from `test-mbco-lavaan.R` the 30 existing cases that still apply; each keeps its
   assertion, only the fitter changes. The `:=`, equality, fixed-path and refusal cases port as-is.
3. `mbco_d4(model = )` equals `infer(type = "mbco")` on the same imputations (existing test).
4. New: C1 label injection on unlabeled, labeled, covariate, and multi-line syntax; refusal
   messages for C2.
5. Calibration is not re-run: statistic identical to 1e-11 (section 1). The glm vs lavaan
   agreement test (`test-mbco-lavaan.R:25`) stays as the cross-engine guard.
6. Evidence for the PR: `make ci` counts plus the parity table.

## 5. Tasks

| T | Task | Size |
|---|---|---|
| T1 | `.mm_sem_label_model()` + tests (C1) | M |
| T2 | `.mm_sem_provider()`, parity oracle, planted defect (C5, section 1) | M |
| T3 | `.mm_sem_check_args()` allow-list and refusals (C2, C3) | S |
| T4 | Wire `infer()` and `mbco_d4(model = )`; remove lavaan provider, MLR code and harness (C4) | M |
| T5 | Port the remaining `test-mbco-lavaan.R` cases | M |
| T6 | `DESCRIPTION` floor, NEWS (Breaking changes: C2, C4, C6), vignette `lavaan-sem` | S |
| T7 | `make ci`, PR into `dev` | S |

## 6. Questions for the author

1. **C2 allow-list**: accept the narrowing (refuse `likelihood`, `conditional.x`, `missing`, etc. for
   `infer(type = "mbco")`)? Alternative: keep them working by leaving those cases on the lavaan
   provider, which contradicts "replace".
2. **C6 timing**: merge to `dev` now (r-universe serves it; CRAN already blocked on RMediation 1.7.1),
   or hold the branch until medfit 0.10.0 is on CRAN?
3. **C4**: delete the MLR internals and harness, as proposed, or keep the harness for a later rerun?

Recommended answers: 1 accept; 2 merge to `dev` now, since r-universe has medfit 0.10.0 and
`dev` is not a release; 3 delete (the gate failed and the result is recorded).
