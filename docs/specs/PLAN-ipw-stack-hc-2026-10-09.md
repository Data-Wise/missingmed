# PLAN: HC-corrected stacked IPW variance, and the fixes the first grid exposed

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Follows** | [SPEC-ipw-stack-coverage-2026-10-09.md](SPEC-ipw-stack-coverage-2026-10-09.md) section 13 (option 1) and [NOTE-ipw-weight-score-stacking-2026-10-09.md](NOTE-ipw-weight-score-stacking-2026-10-09.md) |
| **Status** | DRAFT for author review. Per the spec-driven workflow, T1 is a spec that needs approval before any code. |

## Overview

The first coverage grid found no default change warranted. Three things it exposed need work: the stacked estimator is HC0-type while the shipped path is HC3 (the larger part of the stacked deficit); the grid's `aux`/`auxm` DGMs misspecify the joint missingness model by construction; and `auxm` shows bias in `b` under heavy weights that hurts even the shipped intervals. This plan fixes the estimator, repairs the experimental design, adds the diagnostics needed to explain the bias, repeats the gate under pre-registered criteria, and only then decides on wiring. One piece (documenting the heavy-weight finding) does not depend on any of it and ships first.

## What "other fixes" means here (author: correct this list)

| # | Fix | Why |
|---|---|---|
| F1 | HC correction for the stacked variance (variants `HC1`, `HC3`) | the HC0 -> HC3 gap is 2-3x the weight-estimation effect |
| F2 | DGMs where each joint form is correctly specified (`auxj`, `auxmj`: M and Y missing together through one logistic), keep independent-missingness DGMs for `spv` | spec section 2's premise was false for joint forms |
| F3 | Weight diagnostics (effective sample size, largest weight share, trimmed share) per replication, and a milder-slope DGM (`auxm_mild`, `Z` slope 0.5) | tells heavy-weight finite-sample bias from misspecification and shows a dose-response |
| F4 | Population truth instead of nominal `a*b`; cell-specific seeds | seeds `5000 + rep` repeat across cells; nominal truth is off by up to 0.002 |
| F5 | IPW docs: the heavy-weight and trimming findings, `spv` for variable-specific missingness | true regardless of what stacking decides; ships first |
| F6 | Wiring (`weights_known`, docs, NEWS) | **only if** the gate says so |

Out of scope, recorded: lavaan stacking (needs a `lavScores()` check), binary-outcome block, misspecified missingness models, `weights_known` default before the decision.

## Architecture decisions

1. **The HC variants are pre-declared, not searched.** `HC3` (primary: mirrors medfit's `sandwich::vcovHC` default) and `HC1` (secondary: `n_cc / (n_cc - p)`). The decision rule picks the primary if it passes, else the secondary if it passes; no third variant after seeing results.
2. **Leverage enters the regression-score term only.** For each regression the influence of a complete case is `psi_i / (1 - h_i)^d` with `h_i = hatvalues(fit)` (the weighted-regression leverage) and `d = 1` (HC2) or `2` (HC3); the weight-model score term `G H^{-1} S_i` is left uncorrected in the first version (it has no regression leverage; a missingness-model leverage is a possible later variant). Known answer: with the weight-score blocks removed this must equal `sandwich::vcovHC(fit, type = "HC3")` exactly.
3. **One run, all arms.** Every replication reports `known_hc3`, `known_hc0`, `stacked_hc0`, `stacked_hc1`, `stacked_hc3` on the same data, so every comparison is paired.
4. **Joint-form DGMs are separate from independent-missingness DGMs**, and each form is judged only where it is correctly specified: joint forms on `auxj`/`auxmj` (and `std`), `spv` on `aux`/`auxm`/`auxm_mild`. Cross-checks on misspecified cells are reported, not decisive.
5. **Gate first, wiring after.** No `run()` change, no `weights_known` argument and no default change before the decision table exists.

## Dependency graph

```
T0 docs PR (F5)  ................................ independent, ship first
T1 SPEC v2 (gate 2) -- author approval --> everything below
   |
T2 HC variants in .ipw_stacked_vcov (TDD, laptop)
   |
T3 harness v2: arms, DGMs, diagnostics, truth, seeds (laptop controls)
   |
T4 combine v2 (criteria, variant rule) + selftest
   |
T5 hopper pilot -> T6 full run -> T7 results and decision
   |
T8 (gated) wiring: weights_known, docs, NEWS  --or--  T8' close out: document, keep internal
```

Sequential except T0, which is independent. T4 can be written alongside T3 (different files).

## Tasks

### T0: documentation of the finding (size S, independent)
- **Acceptance:** `vignettes/articles/ipw-weighting.Rmd` "Standard errors" and "Stabilizing and trimming" gain: known-weights HC3 intervals under-cover under heavy weights (coverage 0.90 to 0.93 in the worst grid cells, bias in `b`), trimming at 0.95 added bias in those cells (b = 0.237 to 0.264 against 0.30), and a variable-specific missingness mechanism calls for a per-variable `weight_formula` (the joint model cannot represent a product of logistics). Every figure quoted is in `RESULTS-ipw-stack-coverage-2026-10-09.txt`. NEWS Documentation bullet.
- **Verify:** article renders with every chunk evaluated; `devtools::check(args = c("--as-cran", "--no-manual"))` 0/0/0; each quoted number is grep-able in the RESULTS file.
- **Files:** `vignettes/articles/ipw-weighting.Rmd`, `NEWS.md`.

### T1: SPEC v2 for the second gate (size S, needs approval)
- **Acceptance:** `docs/specs/SPEC-ipw-stack-hc-gate-2026-10-09.md` covering the six spec areas, with the arms, the DGM table (`std`, `aux`, `auxm`, `auxj`, `auxmj`, `auxm_mild`), cells (6 DGM x 2 n x 2 miss x 4 points = 96), criteria C1-C5 (bars as in addendum A2, unchanged), the variant rule (architecture decision 1), the per-form "where correctly specified" rule (decision 4), controls, and what each outcome means for T8. Pre-registers the bar, so nothing is chosen after the run.
- **Verify:** the author approves; spec states what would make the primary variant fail and what follows.
- **Files:** the new spec only.

### T2: HC variants in `.ipw_stacked_vcov()` (size M)
- **Acceptance:** `.ipw_stacked_vcov(fits, info, hc = c("HC0", "HC1", "HC3"))`, default `"HC0"` so nothing existing changes; `HC3` scales each complete case's `psi_i` by `1 / (1 - h_i)^2`, `HC1` the whole variance by `n_cc / (n_cc - p)` per regression.
- **Verify (tests first):** (a) with `info$blocks` removed, `hc = "HC3"` equals `sandwich::vcovHC(fit, type = "HC3")` per regression to 1e-8, `"HC1"` equals type `"HC1"`; (b) the existing brute-force equalities for `"HC0"` still pass (stabilized, per-variable, trimmed); (c) planted defect: use `h_i` of the unweighted regression and confirm (a) fails; (d) `h_i >= 1` (a leverage-one case) gives a clear error, not `Inf`.
- **Files:** `R/ipw_stack.R`, `tests/testthat/test-ipw-stack.R`.

### T3: harness v2 (size M)
- **Acceptance:** `one_ipw()` reports the five arms plus the control arm, and per replication the effective sample size `(sum w)^2 / sum w^2`, the largest weight share, the trimmed share; `ipw_cells()` returns 96 cells with the new DGMs; `gen_ipw()` supports a simultaneous-missingness DGM (one logistic for "M and Y both observed") and a `Z` slope parameter; truth from a 2e6-row complete-data regression per (DGM, point), stored; seeds `5000 + 100000 * cell + rep`.
- **Verify:** T1-style checks (96 cells, truth vs nominal within 0.005, missing shares within 0.02, stored definitions identical in a fresh process, planted defect caught); controls 1 and 3 rerun; **new control:** on `auxj` the joint missingness model is correctly specified, shown by the unweighted-vs-weighted estimates agreeing with truth at n = 2000 (bias of `b` below 0.01).
- **Files:** `dev/sim-ipw-stack-lib.R`, `dev/sim-ipw-stack-smoke.R`, `dev/sim-ipw-stack-cells.rds` (or a v2 file).

### T4: combine v2 (size M)
- **Acceptance:** criteria per form and arm with the "correctly specified where decisive" rule, the variant rule, ESS summaries by cell, bias of `a`, `b`, `a*b` by cell, and the dose-response table (`auxm` vs `auxm_mild`).
- **Verify:** selftest with planted outcomes (primary variant passes -> adopted; primary fails and secondary passes -> secondary; both fail -> neither; a misspecified-cell failure does not decide) and the all-dropped case from before.
- **Files:** `dev/sim-ipw-stack-combine.R`.

### T5 / T6: hopper pilot and full run (size S each)
- **Acceptance:** `dev` build with T2 installed on hopper (backup first); pilot (2 cells x 20 reps) clean; full run 96 cells x 4 chunks = 384 tasks, all COMPLETED. Roughly 0.2 s per replication, about 11 core-hours, under an hour wall at `%40`.
- **Verify:** `sacct` states; pilot per-column failure shares read before T6.

### T7: results and decision (size S)
- **Acceptance:** spec section with the decision table per weight form and variant; the dose-response and ESS findings; `RESULTS` file; `.STATUS`.
- **Verify:** every pre-registered criterion has a PASS/FAIL line.

### T8 (gated) or T8': wiring or close-out
- **T8 if a variant passes C1-C3 for a weight form:** `weights_known` argument on `set_md_mediation()` (default decided by the table), `run()` stores the stacked matrix, `pool()` passes it through, docs and NEWS, refcard row; E2E on a real `run() -> pool() -> infer()` against the grid's interval. A separate PR and plan.
- **T8' otherwise:** record that stacking stays internal, close item E, keep `R/ipw_stack.R` with its tests as a documented internal.

## Checkpoints

- **After T1:** author approves the spec. No code before.
- **After T2:** all known-answer equalities hold. Do not build a harness on an estimator that fails its own anchor.
- **After T3/T4:** controls and selftest pass on the laptop.
- **After T5:** pilot failure shares read.
- **After T7:** decision table exists before T8 is planned.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| HC3 on the `psi` term alone is a heuristic for the stacked influence function | corrected stacked may still under-cover in `aux` (the weight-score term added failures there) | the grid decides; a missingness-model-leverage variant is a recorded follow-up, not added after the fact |
| Heavy-weight bias persists in `auxm` and `spv` | coverage fails for every arm, no variance fix helps | F3 diagnostics and the mild-slope DGM separate it; the result is reported as an IPW finding, T0 documents it |
| More arms and cells raise multiplicity | false failures | same 3-se bars and pre-registered borderline rerun as addendum A2; the variant rule limits the choices to two |
| `auxj` DGM changes the missingness structure | joint-form comparison not comparable with the first grid | stated in T1; the first grid's results stay as recorded |
| Scope creep into lavaan or binary outcomes | delay | out of scope, listed |

## Open questions for the author

1. **Is the "other fixes" list (F2-F5) what you meant?** Say what to add or drop.
2. **F2: add `auxj`/`auxmj` joint-simultaneous DGMs (recommended)** versus judging only `spv` on the independent DGMs. Recommended because the default `weight_formula = NULL` is the joint model, which most users run.
3. **F3: include the mild-slope DGM `auxm_mild` (recommended).** It is the cheapest test of whether the `auxm` bias is a heavy-weight effect.
4. **T0 now, in parallel (recommended)** or after the gate. It documents a measured fact and does not depend on stacking.
5. **HC variants:** `HC3` primary and `HC1` secondary as written, or add `HC2`.
