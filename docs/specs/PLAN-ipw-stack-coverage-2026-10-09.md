# PLAN: coverage gate for the stacked IPW variance

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Spec** | [SPEC-ipw-stack-coverage-2026-10-09.md](SPEC-ipw-stack-coverage-2026-10-09.md) (approved) |
| **Status** | DRAFT for author review. Nothing is built until the plan is approved. |
| **Location** | `docs/specs/` (repo convention), not the skill's default `tasks/plan.md`. |

## Overview

Build a hopper harness that simulates 48 cells x 2000 replications, evaluates 4 weight forms with both the known-weights and the stacked `a*b` interval on identical data, and reports criteria C1-C5, the controls and the per-weight-form decision. The result decides step 4 of the stacking note (wiring and the default).

## Dependency graph

```
#70 per-variable guard (merge first: the per-variable arm needs both M and Y covered)
   |
T1 cells + DGM + truth check
   |
T2 one replication (all arms, control arm) + laptop controls 1 and 3
   |
T3 hopper task script + sbatch + combine (criteria logic, planted-result test)
   |
T4 hopper pilot (2 cells x 20 reps) + install the dev build on hopper
   |
T5 full run (192 tasks)
   |
T6 combine -> results section, decision table, RESULTS file
   |
(gated by the decision) note step 4: wire into run(), weights_known, docs, NEWS
```

Strictly sequential: each task's output is the next one's input, and T4's per-column failure shares can change the design (T5 must not start before they are read). Nothing is parallel except T3's `combine` script and the hopper wrapper, which touch different files and can be written together.

## Tasks

### T1: cells, DGM, truth (size S)

- **Acceptance:** `ipw_cells()` returns 48 rows (3 DGM x 2 n x 2 miss x 4 points); `gen_ipw(cell, seed)` returns a data frame with `M` and `Y` incomplete at the cell's per-variable rate (within 0.02 of nominal on a 2e5-row draw); intercepts solved once per DGM and rate; `truth_ab(cell)` from a 2e6-row complete-data regression matches the nominal `a*b` within 0.005 for every cell (the `auxm` structural `b_s` correction is what is being tested); a stored copy of the 48 definitions is committed and compared.
- **Verify:** `Rscript dev/sim-ipw-stack-smoke.R --defs` prints "48 cells, truth within 0.005, rates within 0.02" and fails loudly otherwise; planted defect: omit the `auxm` correction and confirm the truth check fails.
- **Files:** `dev/sim-ipw-stack-lib.R`, `dev/sim-ipw-stack-smoke.R`, `dev/sim-ipw-stack-cells.rds` (stored definitions).

### T2: one replication and the laptop controls (size M)

- **Acceptance:** `one_ipw(cell, seed)` returns one row per weight form with `a`, `b`, both `a*b` intervals (`dop`, level 0.95), widths, covers/rejects flags, `n_cc`, `n_trim`, `refused`, `pd_stacked`, `na_interval`, plus the control arm (model-based covariance, unstabilized joint). Seeds are `5000 + rep`. A glm refit that refuses or fails is recorded, not dropped.
- **Verify:** (control 1) on 50 replications per DGM the known interval equals `infer(type = "mc")` of the real `run()` -> `pool()` result, endpoints within 0.01; (control 3) stacked SE versus a bootstrap oracle on 3 draws, ratio in [0.90, 1.10]; 20 replications of one cell run in under 10 seconds.
- **Files:** `dev/sim-ipw-stack-lib.R`, `dev/sim-ipw-stack-smoke.R`.

### T3: hopper task script, sbatch, combine (size M)

- **Acceptance:** one array task = one chunk of one cell (cell = (t-1) %/% 4 + 1, chunk = (t-1) %% 4), `ONLY_CELLS` and `REPS` for pilots, as `dev/sim-glm-mbco-hopper.R`. `combine` reads the task files and prints, per DGM x weight form: size at P1-P3, coverage and power at P4 for both arms, paired discordant counts with exact McNemar, median width ratio, failure shares per column, criteria C1-C5 with PASS/FAIL, the control-arm check, and the decision per weight form from the rule in spec section 3.
- **Verify:** `combine` run on synthetic task files with planted outcomes (a stacked arm made liberal in one cell; a column with 3% dropped replications) flags exactly those, and the decision table follows the rule; run on the T2 smoke output without error.
- **Files:** `dev/sim-ipw-stack-hopper.R`, `dev/sim-ipw-stack.sbatch`, `dev/sim-ipw-stack-combine.R`.

### T4: hopper pilot (size S)

- **Acceptance:** `dev` build of missingmed (containing `.ipw_stacked_vcov()` and the #70 guard) installed to `~/Rlib-sem` on hopper; pilot `ONLY_CELLS=1,40 REPS=20 sbatch --array=1-8` completes; pilot `combine` runs; per-column failure shares read and recorded in the spec before T5.
- **Verify:** all pilot tasks COMPLETED in `sacct`; pilot sizes are not compared (20 reps), only the plumbing and failure shares. If any failure column exceeds 1%, stop and discuss before T5.
- **Files:** none in the repo (hopper side); a one-line result in the spec.

### T5: full run (size S, wall time about an hour)

- **Acceptance:** `sbatch --array=1-192%40` completes; 192 task files present; no task FAILED.
- **Verify:** `sacct` state counts; file count; `secs` per task recorded.

### T6: results and decision (size S)

- **Acceptance:** `combine` output committed as `docs/specs/RESULTS-ipw-stack-coverage-2026-10-09.txt`; spec section 8 written with the decision table per weight form and any conditional columns marked; `.STATUS` updated.
- **Verify:** every criterion in spec section 3 has a PASS/FAIL line; the controls are reported first.

## Checkpoints

- **After T2 (laptop):** controls 1 and 3 pass and truth/definitions are stable. Do not write hopper scripts on a harness that fails its own controls.
- **After T4 (pilot):** failure shares read. Do not launch T5 on an unexamined pilot.
- **After T6:** the decision table exists. Only then is note step 4 planned; its default is not touched before.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Harness plumbing differs from the shipped path | Grid tests the wrong thing | Control 1 (known arm = shipped `infer(mc)`), run before any hopper work |
| `auxm` truth wrong | Coverage biased in a whole DGM | Numerical truth check per cell in T1, planted-defect test |
| Failure columns above 1% (refused fits, non-PD stacked block) | Sizes conditional | Per-column shares in T4 and in `combine`; conditional cells marked |
| Pilot looks fine, full run reveals a class of failure | Wasted hour | The full run is cheap (about 1 core-hour per 10 cells); rerun is affordable |
| Dev build on hopper out of date | Grid runs old code | T4 records `packageVersion` and the commit SHA in the pilot output |
| Trimmed weights fail C1 | Stacked unavailable for trim | Decision rule already refuses stacking with `weight_trim < 1` |

## Open questions

- None blocking. One for later: whether the binary-outcome block (spec section 8) is planned now or after T6; the spec says after.

## Definition of done

All of spec section 3's criteria evaluated on the full run, controls passed and reported, decision table written per weight form, results committed, `.STATUS` updated. Note step 4 is then planned separately.
