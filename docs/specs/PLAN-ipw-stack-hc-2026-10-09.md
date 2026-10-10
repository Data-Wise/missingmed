# PLAN: HC-corrected stacked IPW variance, and the fixes the first grid exposed

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Follows** | [SPEC-ipw-stack-coverage-2026-10-09.md](SPEC-ipw-stack-coverage-2026-10-09.md) section 13 (option 1) and [NOTE-ipw-weight-score-stacking-2026-10-09.md](NOTE-ipw-weight-score-stacking-2026-10-09.md) |
| **Status** | DRAFT for author review (revised after an advisor review the same day). Per the spec-driven workflow, T1 is a spec that needs approval before any code. |

## Overview

The first coverage grid found no default change warranted. Three things it exposed need work: the stacked estimator is HC0-type while the shipped path is HC3 (the larger part of the stacked deficit); the grid's `aux`/`auxm` DGMs misspecify the joint missingness model by construction; and `auxm` shows bias in `b` that hurts even the shipped intervals. The bias has two separate causes (spec section 14): the joint forms are structurally biased (misspecified model; 0.278 at n = 1e5), `spv` has a finite-sample bias that vanishes by n of about 5000. This plan fixes the estimator, repairs the experimental design, adds the diagnostics needed to explain the bias, repeats the gate under pre-registered criteria, and only then decides on wiring. One piece (documenting the heavy-weight finding) does not depend on any of it and ships first.

## What "other fixes" means here (author: correct this list)

| # | Fix | Why |
|---|---|---|
| F1 | HC correction for the stacked variance (variants `HC1`, `HC3`) | the HC0 -> HC3 gap is 2-3x the weight-estimation effect |
| F2 | DGMs where each joint form is correctly specified (`stdj`, `auxj`, `auxmj`: M and Y missing together through one logistic), and independent-missingness DGMs (`std`, `aux`, `auxm`) judged on `spv` only | spec section 2's premise was false for joint forms, **including `std`** (two independent logistics) |
| F3 | Weight diagnostics (effective sample size, largest weight share, trimmed share) per replication. The mild-slope DGM is **dropped**: the large-n check (spec section 14) already separates finite-sample from structural bias | cheap, and ties bias to ESS |
| F4 | Population truth instead of nominal `a*b`; cell-specific seeds | seeds `5000 + rep` repeat across cells; nominal truth is off by up to 0.002 |
| F5 | IPW docs: the joint default is structurally biased when missingness is variable-specific (use a per-variable `weight_formula`), trimming added bias, and heavy-weight finite-sample bias that fades with n | true regardless of what stacking decides; ships first, with the diagnostic script and output |
| F6 | Wiring (`weights_known`, docs, NEWS) | **only if** the gate says so |
| F7 | **Decision for the author, no code planned:** the default missingness model (`weight_formula = NULL`) is the joint model, which is misspecified whenever M and Y are missing for separate reasons. Options: keep and document (F5), warn when more than one model variable is incomplete, or default to the per-variable factorization. A default change alters every user's IPW estimate | the joint model is what most users run and what the large-n check shows to be biased in the `auxm` mechanism |

Out of scope, recorded: lavaan stacking (needs a `lavScores()` check), binary-outcome block, misspecified missingness models, `weights_known` default before the decision.

## Architecture decisions

1. **The HC variants are pre-declared, not searched.** `HC3` (primary: mirrors medfit's `sandwich::vcovHC` default) and `HC1` (secondary: `n_cc / (n_cc - p)`). The decision rule picks the primary if it passes, else the secondary if it passes; no third variant after seeing results.
2. **Leverage enters the regression-score term only, and the exponent is per row of the influence, not of the variance.** The meat is `crossprod(U)`, so a row factor is squared. For each regression the influence of a complete case is `psi_i / (1 - h_i)` for **HC3** (the variance then carries `1 / (1 - h_i)^2`, as in `sandwich`) and `psi_i / sqrt(1 - h_i)` for HC2, with `h_i = hatvalues(fit)` (weighted-regression leverage). **HC1** scales each regression's columns of `U` by `sqrt(n_cc / (n_cc - p_r))` with that regression's `p_r`, so `cov(a, b)` is well defined and each diagonal block still matches `vcovHC(type = "HC1")`. The weight-model score term `G H^{-1} S_i` is left uncorrected in the first version. Known answer: with the weight-score blocks removed, `HC3` must equal `sandwich::vcovHC(fit, type = "HC3")`, and `HC1` type `"HC1"`, per regression, to 1e-8. If a test fails, the implementation is wrong; do not loosen the tolerance.
3. **One run, all arms.** Every replication reports `known_hc3`, `known_hc0`, `stacked_hc0`, `stacked_hc1`, `stacked_hc3` on the same data, so every comparison is paired.
4. **Joint-form DGMs are separate from independent-missingness DGMs**, and each form is judged only where it is correctly specified: joint forms (`uj`, `sj`, `sjt`) on `stdj`/`auxj`/`auxmj`, `spv` on `std`/`aux`/`auxm`. Cross-checks on misspecified cells are reported, not decisive. (`std` was wrongly listed as correctly specified for joint forms in an earlier draft of this plan.)
5. **Gate first, wiring after.** No `run()` change, no `weights_known` argument and no default change before the decision table exists.

## Dependency graph

```
T0 docs PR (F5) + diagnostic script ............ no dependency on stacking; evidence is spec section 14
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
- **Acceptance:** `vignettes/articles/ipw-weighting.Rmd` "Standard errors", "Choosing the missingness model" and "Stabilizing and trimming" gain, with the wording of spec section 14 and **not** "heavy weights" for the joint-form bias: (i) when missing values in different variables arise separately, the default joint model is misspecified and `b` plateaus below the truth (0.278 against 0.30 at n = 1e5); a per-variable `weight_formula` removes it; (ii) with correctly specified weights a finite-sample bias remains at small complete-case counts (about -0.02 at n = 200 to 500 with 40% missing in that mechanism, gone by n of about 5000); (iii) trimming at 0.95 added bias in those cells (b = 0.237 to 0.264); (iv) intervals under known weights under-cover accordingly (0.90 to 0.93 in the worst cells). Every figure is in a committed RESULTS file. NEWS Documentation bullet.
- **Verify:** the diagnostic (`dev/sim-ipw-auxm-bias.R`, the two laptop checks of section 14 in one script) reruns and reproduces the table within Monte-Carlo error; article renders with every chunk evaluated; `devtools::check(args = c("--as-cran", "--no-manual"))` 0/0/0; each quoted number is grep-able.
- **Files:** `vignettes/articles/ipw-weighting.Rmd`, `NEWS.md`, `dev/sim-ipw-auxm-bias.R`, `docs/specs/RESULTS-ipw-auxm-bias-2026-10-09.txt`.

### T1: SPEC v2 for the second gate (size S, needs approval)
- **Acceptance:** `docs/specs/SPEC-ipw-stack-hc-gate-2026-10-09.md` covering the six spec areas, with the arms, the DGM table (`std`, `aux`, `auxm`, `auxj`, `auxmj`, `auxm_mild`), cells (6 DGM x 2 n x 2 miss x 4 points = 96), criteria C1-C5 (bars as in addendum A2, unchanged), the variant rule (architecture decision 1), the per-form "where correctly specified" rule (decision 4), controls, and what each outcome means for T8. Pre-registers the bar, so nothing is chosen after the run.
- **Verify:** the author approves; spec states what would make the primary variant fail and what follows.
- **Files:** the new spec only.

### T2: HC variants in `.ipw_stacked_vcov()` (size M)
- **Acceptance:** `.ipw_stacked_vcov(fits, info, hc = c("HC0", "HC1", "HC3"))`, default `"HC0"` so nothing existing changes; `HC3` scales each complete case's row of `psi_i` by `1 / (1 - h_i)` (the variance then carries the square, as in `sandwich`), `HC1` scales each regression's columns of `U` by `sqrt(n_cc / (n_cc - p_r))` (architecture decision 2).
- **Verify (tests first):** (a) with `info$blocks` removed, `hc = "HC3"` equals `sandwich::vcovHC(fit, type = "HC3")` per regression to 1e-8, `"HC1"` equals type `"HC1"`; (b) the existing brute-force equalities for `"HC0"` still pass (stabilized, per-variable, trimmed); (c) planted defects, each of which must fail (a): use `h_i` of the unweighted regression; use `1 / (1 - h_i)^2` on `psi_i` (the exponent error); (d) `h_i >= 1` (a leverage-one case) gives a clear error, not `Inf`.
- **Files:** `R/ipw_stack.R`, `tests/testthat/test-ipw-stack.R`.

### T3: harness v2 (size M)
- **Acceptance:** `one_ipw()` reports the five arms plus the control arm, and per replication the effective sample size `(sum w)^2 / sum w^2`, the largest weight share, the trimmed share; `ipw_cells()` returns 96 cells over six DGMs (`std`, `aux`, `auxm` independent missingness; `stdj`, `auxj`, `auxmj` simultaneous); `gen_ipw()` supports a simultaneous-missingness DGM (one logistic for "M and Y both observed") and a `Z` slope parameter; truth from a 2e6-row complete-data regression per (DGM, point), stored; seeds `5000 + 100000 * cell + rep`.
- **Verify:** T1-style checks (96 cells, truth vs nominal within 0.005, missing shares within 0.02, stored definitions identical in a fresh process, planted defect caught); controls 1 and 3 rerun; **new control:** the large-n check of spec section 14 as a harness test: on `auxj`/`auxmj`/`stdj` the joint forms recover `b` at n = 1e5 (within 0.01 of 0.30), on `auxm` the per-variable form does and the joint forms do not (so the control can fail).
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
| Finite-sample `spv` bias at small n (about -0.02 at n = 200 to 500) | under-coverage for every arm in those cells whatever the variance | known from spec section 14; the grid reports bias by cell next to coverage, and a cell whose failure is explained by bias is labelled so rather than blamed on the variance |
| More arms and cells raise multiplicity | false failures | same 3-se bars and pre-registered borderline rerun as addendum A2; the variant rule limits the choices to two |
| `auxj` DGM changes the missingness structure | joint-form comparison not comparable with the first grid | stated in T1; the first grid's results stay as recorded |
| Scope creep into lavaan or binary outcomes | delay | out of scope, listed |

## Open questions for the author (with recommended defaults)

1. **Is the F2-F5 list what you meant by "other fixes"? Recommended: yes, plus F7 as a decision.** F7 is new: the default joint missingness model is biased at any n when missing values arise separately in M and Y (spec section 14).
2. **F2: add the simultaneous-missingness DGMs `stdj`, `auxj`, `auxmj` (recommended).** The default `weight_formula = NULL` is the joint model.
3. **F3: diagnostics only, drop the mild-slope DGM (recommended).** The large-n check made it unnecessary.
4. **T0 now (recommended), with the new wording and the committed diagnostic script.** It no longer says "heavy weights" for the joint-form bias.
5. **HC variants: `HC3` primary and `HC1` secondary as written (recommended).** Add `HC2` only if you want it reported.
6. **F7: keep the joint default and document it for now (recommended).** Changing it, or warning when more than one model variable is incomplete, is a separate decision that alters users' estimates; it deserves its own spec.
