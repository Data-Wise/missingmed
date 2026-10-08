# REPORT: lavaan 0.7-3 and what it means for missingmed

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Scope** | Changes between lavaan 0.7-2 (2026-07-16) and 0.7-3 (CRAN, published 2026-10-08), and their effect on missingmed 0.6.0 |
| **Method** | Installed 0.7-3 in a scratch library (the main library still has 0.7-2); diffed the two CRAN source tarballs; re-ran the constraint tests and missingmed's suite on both. Neither tarball ships a NEWS file and none was found on GitHub or CRAN, so **the changes below are read from the code diff, not from release notes**. |
| **Labels** | **[V]** verified by a command; **[R]** read from code or comments only, not run; **[?]** unknown |

## Summary

- **The author's report is confirmed, in a specific form.** In lavaan 0.7-2, requesting `optim.parscale = "standardized"` on a model with constraints returns `converged = TRUE` while **violating the constraints**. lavaan 0.7-3 refuses to rescale and warns **[V]**.
- **missingmed's shipped behavior is unaffected on 0.7-3**: the full suite gives the same result on both versions **[V]**.
- **Action for missingmed:** raise the `lavaan` floor in `DESCRIPTION` to `>= 0.7-3`, or document the hazard. Recommended: raise the floor when the SEM-MBCO work (constrained refits) starts; until then, document that `fit_args = list(optim.parscale = ...)` with constraints needs lavaan >= 0.7-3.

## 1. The constraint flaw [V]

Model `M ~ a*X; Y ~ b*M + cp*X` (n = 300), `optim.parscale = "standardized"`:

| Constraint | Required | lavaan 0.7-2 result | lavaan 0.7-3 result |
|---|---|---|---|
| `a + b == 0.5` | a + b = 0.5 | **a + b = 1.887**, `converged` TRUE, no warning | a + b = 0.5000, warning "optim_parscale is ignored" |
| `a == 2*b` | a = 2b | **a = b = 0.320**, `converged` TRUE | a = 0.395, b = 0.1975 |
| `a*b == 0.05` (nonlinear) | a*b = 0.05 | **a*b = 0.0515**, `converged` TRUE | a*b = 0.0500 |

- Without `optim.parscale`, both versions satisfy every constraint (`a + b` = 0.5000 on both) **[V]**. The earlier constraint test (`a*b == 0`, `a*b == 0.05`, `a^2 + b^2 < 0.01`) gives identical output on 0.7-2 and 0.7-3 **[V]**.
- **Cause, from 0.7-3's added comments [R]:** the scaling layer imposes constraints on the *scaled* parameters. That is harmless for box bounds and simple `a == b` equalities, but `a + b == 3` becomes `a + b == 3/scale`, `a == 2*b` becomes `a == b`, and nonlinear equalities and inequalities are evaluated in the wrong metric. The comment also says that, without the fix, "a 'converged' solution could be returned that violates the constraints the user asked for".
- **Possible wider exposure in 0.7-2 [R, not reproduced]:** the new code also skips "the rescaling attempts (2 and 4) of the retry cascade" when constraints are present. So in 0.7-2, a hard problem that failed its first attempt may have been retried with scaling and returned a constraint-violating "converged" fit. I did not trigger this path.
- **Fix in 0.7-3 is a stopgap [R]:** the comments call it that. A proper fix (scaling applied correctly to constraints) is not there.

## 2. Other changes in 0.7-3 [R unless noted]

| Change | Size | Relevance to missingmed |
|---|---|---|
| Source grows from 132,422 to 149,999 lines of R; about 13,900 changed lines; 9 R files and 3 help pages added, 1 R file removed (`lav_cfa_jamesstein.R`) **[V]** | large release | The package is a fast-moving dependency; re-run missingmed's suite on each release |
| New exports `lavTestNET` (nesting and equivalence tests) and `lavH1` (saturated model only) **[V]** | additive | None now |
| New `information.meat.hc` small-sample corrections for the sandwich (`lav_vcov_hc.R`), per its file header | additive | May matter for IPW with `se = "robust.huber.white"` (G1); not tested, not adopted |
| New James-Stein estimator (`lav_sem_js*.R`, `estimator_js.Rd`) | additive | None |
| New delta-method SEs for noniterative estimators (`lav_optim_noniter_vcov.R`) | additive | None |
| Start-value fix for the internal rescaling: latent-variable variances now start from the marker indicator's variance, not 1.0 | behavior | Could change convergence for latent mediators on badly scaled data; **no change observed** on the test suite |
| `Imports` gains `parallel` and `grDevices` **[V]** | dependency | Two base-R packages; no install cost |
| No-doc: internal variable rescaling for badly scaled data was **new in 0.7-2** (`lav_rescale.R`) | earlier release | This is the feature the constraint fix guards |

## 3. Effect on missingmed 0.6.0 [V]

Full `devtools::test()` on `origin/dev` at `baa51e5`, same checkout, only lavaan changed:

| lavaan | tests | failed | errors | skipped | warnings | expectations |
|---|---|---|---|---|---|---|
| 0.7-2 | 317 | 0 | 0 | 9 | 0 | 1200 |
| 0.7-3 | 317 | 0 | 0 | 9 | 0 | 1200 |

- missingmed calls `lavaan::sem`, `lavaanify`, `lavNames` and `lavInspect` only (13 call sites) **[V]**; none touches the added or removed exports.
- `DESCRIPTION` has `lavaan (>= 0.6-0)`, so users on lavaan 0.6-x or 0.7-2 are supported but may hit the constraint flaw above if they pass `optim.parscale` through `fit_args`.
- No shipped missingmed feature imposes lavaan constraints today. The SEM-MBCO follow-up (spec Q4) plans `lavaan::sem(constraints = "a == 0")`. A constant-target equality like `a == 0` is rescale-safe (0 scaled is 0), but any nonzero target or the `a*b == 0` form is not.

## 4. Implications

| # | Implication | Recommended action |
|---|---|---|
| 1 | The flaw is real but only reachable through `optim.parscale` (explicit) or, by code reading, the retry cascade | Document in `set_md_mediation()` / `fit_args` help: with constraints, use lavaan >= 0.7-3 |
| 2 | The floor `lavaan (>= 0.6-0)` is far below the version with the constraint guard | Raise to `>= 0.7-3` in the SEM-MBCO PR, since that work imposes constraints; not needed for 0.6.0 behavior |
| 3 | The fix is a stopgap, and the release is large (+17,500 lines) | Keep the parity test in section 1 as a regression test for the MBCO work: a constrained refit must satisfy the constraint to 1e-6 |
| 4 | Bears on the native-engine plan ([PLAN-native-sem-engine-nloptr](../specs/PLAN-native-sem-engine-nloptr-2026-10-08.md)) | It supports the "own the constraint semantics" argument, but not a decision: lavaan's guard now works for the tested cases, and the native engine's `a*b == 0` is start-dependent (see the plan). Add the section 1 table as a parity case for the native engine |
| 5 | NEWS is absent from the package | Track lavaan changes by source diff or the GitHub repository; this report is the first record |

## 5. Not verified

- The retry-cascade exposure in 0.7-2 (section 1).
- Whether `se = "robust.huber.white"` results change with `information.meat.hc` defaults (IPW path).
- Behavior on other lavaan versions in `(>= 0.6-0)`; only 0.7-2 and 0.7-3 were run.
- The 9 skipped tests are identical on both versions; I did not inspect why they skip.

## Reproduction

`dev/spike-lavaan-parscale-constraints.R`. Run it twice, with R_LIBS pointing at a library with lavaan 0.7-2 and at one with 0.7-3.
