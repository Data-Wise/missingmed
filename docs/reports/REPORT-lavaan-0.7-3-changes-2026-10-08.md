# REPORT: lavaan 0.7-3 and what it means for missingmed

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Scope** | Changes between lavaan 0.7-2 (2026-07-16) and 0.7-3 (CRAN, published 2026-10-08), and their effect on missingmed 0.6.0 |
| **Method** | Installed 0.7-3 in a scratch library (the main library still has 0.7-2); diffed the two CRAN source tarballs; re-ran the constraint tests and missingmed's suite on both. Neither tarball ships a NEWS file; the author later supplied lavaan's own release history, <https://lavaan.ugent.be/history/dot7.html> (fetched 2026-10-08), and the sections below now cite it as **[N]**. |
| **Labels** | **[V]** verified by a command; **[R]** read from code or comments only, not run; **[?]** unknown |

## Summary

**Update (17:20, after the author supplied lavaan's release notes):** the notes confirm the constraint flaw as a documented 0.7-2 bug (section 1), and add two findings the code diff did not show: lavaan's snake_case argument rename affects missingmed's IPW guard (section 2a), and 0.7-3 changes marker and runaway-solution behavior (section 2).

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
- **Documented by lavaan [N]** (0.7-2 "Bugs/glitches discovered after the release"): "optim_parscale = \"standardized\" (**also used in the automatic retry attempts when the optimizer fails**): the bounds were not rescaled, and general (in)equality constraints (e.g., a == 2*b) were imposed on the scaled parameters". So the retry-cascade exposure I could only infer from code comments is **confirmed**: in 0.7-2, a constrained fit whose first attempt failed could be retried with scaling and returned violating its constraints, without any `optim.parscale` request from the user. I did not trigger that path myself **[V for the explicit-parscale case; N for the retry path]**.
- A second 0.7-2 bug [N]: a parameter with both bounds that was estimated at its lower bound was not treated as an active constraint when computing SEs.
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
| **Marker handling [N]:** 0.7-2's automatic marker switch could double-scale a factor (negative latent variances) when the marker loading was labeled and constrained, and "silently changed the metric of the latent variable" (lavaan issue 628). 0.7-3 only **warns** about a poor marker; switching needs `bad_marker_switch = TRUE` | behavior | **Relevant to latent mediators.** The latent-mediator `a` and `b` depend on the mediator's metric, so a 0.7-2 fit that auto-switched the marker is not comparable with a 0.7-3 fit. Add a test that the marker is the first indicator and that a poor-marker warning surfaces through `run()` |
| **Runaway solutions [N]:** "the optimizer now detects 'runaway' solutions (where a parameter drifts to infinity) instead of reporting convergence" | behavior | Directly relevant to G2 (convergence refusal): 0.7-2 could report convergence on a drifting fit. Pooling such fits would be a silent error |
| **Snake_case rename [N]:** `sampling.weights` -> `sampling_weights`, `optim.parscale` -> `optim_parscale` and so on; dotted names "still work" but are "deprecated and may be removed in a future release" | API | See section 2a (missingmed's IPW guard) |
| New `information_bread=` and `information_meat_hc=` options (HC1/HC2/HC3 small-sample sandwich corrections) [N] | additive | Candidate for the IPW sandwich SEs; not adopted |
| `estimator = "ML"` now also computes Browne's residual-based test by default [N] | output | Extra summary line; no effect on pooled estimates |
| `rescale_data`: variables with very different variances are internally rescaled by default and the solution is transformed back [N] | behavior | Estimates should be unchanged in the original metric; unchecked on missingmed's models |
| `Imports` gains `parallel` and `grDevices` **[V]** | dependency | Two base-R packages; no install cost |
| No-doc: internal variable rescaling for badly scaled data was **new in 0.7-2** (`lav_rescale.R`) | earlier release | This is the feature the constraint fix guards |

## 2a. A guard in missingmed that the rename defeats [V]

`R/lavaan_spec.R:134` rejects a user-supplied weights argument with `if ("sampling.weights" %in% names(fit_args))`, and `R/run.R:183` passes `sampling.weights = ".md_ipw_w"` to lavaan. Both use the dotted name only. lavaan now accepts `sampling_weights` as a first-class alias [N].

Test on a 200-row model with two different weight columns (same result on 0.7-2 and 0.7-3):

| Call | Coefficient `a` |
|---|---|
| `sampling.weights = "w1"` | 0.32669 |
| `sampling_weights = "w1"` | 0.32669 (alias works) |
| `sampling.weights = "w1"` and `sampling_weights = "w2"` together | 0.32669 (**the dotted one wins; the snake_case one is silently ignored**) |

- So `fit_args = list(sampling_weights = "w")` passes missingmed's G1 guard and is **silently discarded** in favor of the IPW weights. No wrong number results today, but the user's request vanishes without a message, and the guard no longer states what it enforces.
- If lavaan later removes the dotted names (the notes say it "may" [N]), `run.R:183` fails outright.
- The same issue applies to every dotted option missingmed names: `se = "robust.huber.white"`, and `estimator`.
- **Fix (small):** normalize `fit_args` names (dots to underscores, lowercase) before the checks, and pass lavaan the snake_case names. Needs lavaan >= 0.7-2 for the snake_case argument names, which raises the floor (see section 4). Add tests for the snake_case spellings.

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
| 2 | The floor `lavaan (>= 0.6-0)` is far below the versions with the constraint guard (0.7-3), the snake_case names (0.7-2) and the runaway-solution check (0.7-3) | Raise to `>= 0.7-3`. Reasons now include the runaway detection that G2 relies on, not only SEM-MBCO. Recommended in a small PR together with the guard fix in section 2a |
| 3 | The fix is a stopgap, and the release is large (+17,500 lines) | Keep the parity test in section 1 as a regression test for the MBCO work: a constrained refit must satisfy the constraint to 1e-6 |
| 4 | Bears on the native-engine plan ([PLAN-native-sem-engine-nloptr](../specs/PLAN-native-sem-engine-nloptr-2026-10-08.md)) | It supports the "own the constraint semantics" argument, but not a decision: lavaan's guard now works for the tested cases, and the native engine's `a*b == 0` is start-dependent (see the plan). Add the section 1 table as a parity case for the native engine |
| 5 | The package ships no NEWS; the history lives at lavaan.ugent.be | Read <https://lavaan.ugent.be/history/dot7.html> on each release and diff the source when the notes are thin |
| 6 | Latent-mediator metric depends on the marker rule, which changed between 0.7-2 and 0.7-3 [N] | Add a regression test on a poor-marker model and compare `a`/`b` across lavaan versions before claiming latent-mediator results are stable |
| 7 | G2 treats non-convergence as the failure signal, but 0.7-2 reported convergence for runaway solutions [N] | Under lavaan >= 0.7-3 the optimizer flags these; keep the `post.check` warning too |

## 5. Not verified

- The retry-cascade exposure in 0.7-2 was confirmed by lavaan's notes [N] but not reproduced here.
- Whether `se = "robust.huber.white"` results change with `information.meat.hc` defaults (IPW path).
- Behavior on other lavaan versions in `(>= 0.6-0)`; only 0.7-2 and 0.7-3 were run.
- The 9 skipped tests are identical on both versions; I did not inspect why they skip.

## Reproduction

`dev/spike-lavaan-parscale-constraints.R`. Run it twice, with R_LIBS pointing at a library with lavaan 0.7-2 and at one with 0.7-3.
