# SPEC: coverage gate for the stacked IPW variance (a*b interval)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | APPROVED 2026-10-09 ("I approve"). The author did not answer the four questions in section 10 individually; the recommended answer to each was adopted and is recorded there. Plan: [PLAN-ipw-stack-coverage-2026-10-09.md](PLAN-ipw-stack-coverage-2026-10-09.md). |
| **Parent** | [NOTE-ipw-weight-score-stacking-2026-10-09.md](NOTE-ipw-weight-score-stacking-2026-10-09.md) section 6.3 (steps 1-3 merged: #68, #69); plan item E |
| **Decision it serves** | Whether `method = "ipw"` should account for estimating the weights by default (note step 4, the `weights_known` argument), and for which weight forms. |

## 1. Assumptions (correct me now)

1. **Interval under test:** the 95% interval for `a*b` from the distribution of the product (`RMediation::ci(ProductNormal(mu = c(a, b), Sigma), type = "dop")`), built from the 2x2 `a`, `b` block of a covariance matrix. `"dop"` is deterministic and matches the shipped Monte-Carlo interval to about 3e-4 on a test case (checked 2026-10-09: endpoints 0.01925 / 0.18807 against 0.01900 / 0.18810), so the grid avoids 1e5 draws per interval.
2. **Arms:** *known* = today's behavior (block-diagonal, weights treated as known), *stacked* = `.ipw_stacked_vcov()` (full 2x2 block with `cov(a, b)`). Both use identical data and identical point estimates in every replication, so comparisons are paired.
3. **Truth** is the `a*b` of the complete-data population regression for the cell, the quantity IPW targets. The DGMs are built so it is known exactly (section 2).
4. **glm engine only.** lavaan is out of scope until `lavScores()` under `sampling_weights` is checked (note section 5).
5. **hopper** runs it, laptop only for the pilot, per the standing rule (memory `large-sims-go-to-hopper`). The glm calibration's harness layout is the template.
6. **2000 replications per cell** (Monte-Carlo se of a size near 0.05 is 0.0049; the glm gate used 1000 and 0.007). The run is cheap: about 8 glm fits per replication.

## 2. Objective and design

**Objective.** Measure size, coverage, power and width of the `a*b` interval under *known* and *stacked* variances, across weight forms and missingness mechanisms, so the default can be chosen on evidence. Success means a decision per weight form, not a pass/fail of one estimator.

**Data-generating models** (`X`, `C` as in the earlier harnesses; complete data first, then MAR missingness in `M` and `Y`):

| DGM | Mechanism | Why |
|---|---|---|
| `std` | missingness of `M` and `Y` driven by `X`, `C` (in both regressions) | weights nearly ignorable; the oracle found the weight-score term small here |
| `aux` | driven by an auxiliary `Z` that affects `Y` (`zy = 0.7`) and not `M`; `Z` independent of `X`, `C` | classic case for the weight-score correction; marginal `a`, `b` equal the structural values |
| `auxm` | `Z` affects both `M` (`zm = 0.7`) and `Y` (`zy = 0.7`) | shared weights induce `cov(a, b)`; the oracle bootstrap put the correlation as high as 0.42 |

For `auxm` the marginal `b` is `b_s + zy*zm/(1 + zm^2)`, so the structural `b_s` is set to `b_target - 0.49/1.49` and the marginal targets hit the nominal values; the harness verifies truth against a complete-data regression on 2e6 rows (tolerance 0.005) and stops if not.

**Cells** (`DGM` 3 x `n` {200, 500} x missing share {0.25, 0.40} per variable x true point 4 = **48 cells**):

| Point | `a` | `b` | `a*b` | Reads as |
|---|---|---|---|---|
| P1 | 0 | .3 | 0 | size (one path null) |
| P2 | .3 | 0 | 0 | size (other path null) |
| P3 | 0 | 0 | 0 | size (both null) |
| P4 | .3 | .3 | .09 | coverage and power |

Missing share is the per-variable rate, with intercepts solved once per DGM and rate. Each replication evaluates four **weight forms** on the same data: unstabilized joint, stabilized joint, stabilized joint with `weight_trim = 0.95`, stabilized per-variable. So 4 weight forms x {known, stacked} = 8 intervals per replication, plus one **control arm** (section 4). The missingness model is correctly specified (it contains every driver) in all cells; misspecification is out of scope (note section 7).

## 3. Pass criteria (fixed before the run)

Notation: size = rejection rate of `H0: a*b = 0` at P1-P3 (equal to 1 - coverage of 0); coverage at P4; paired comparison on the same replications. Monte-Carlo se of a size near 0.05 is 0.0049 at 2000 replications.

| # | Criterion | Applies to |
|---|---|---|
| C1 | **Validity:** stacked size <= 0.060 in every P1-P3 cell and stacked coverage at P4 >= 0.940 (about 2 se of slack above and below 0.05) | each weight form, per DGM |
| C2 | **Not worse than known:** in no cell is stacked size above known size by more than 0.010, or stacked P4 coverage below known by more than 0.010 | each weight form |
| C3 | **Power:** stacked rejection at P4 within 0.010 of known or better, in every cell | each weight form |
| C4 | **Paired difference reported, not just marginals:** for every cell the discordant counts (known rejects only, stacked rejects only) and exact McNemar p-value, and median width ratio stacked/known | informative; no pass/fail on a single cell |
| C5 | **Failure shares reported per column:** share of replications where a glm refit refused or did not converge, where the stacked `a*b` covariance was not positive definite, or where an interval was `NA` or non-finite. Any column above 1% is named next to the size it affects | informative; a size read from a column with more than 1% dropped replications is marked conditional |

**Decision rule** (per weight form):

- *Stacked becomes the default* if C1, C2 and C3 hold in all 48 cells, **and** in at least one cell the paired difference is significant (McNemar p < 0.01) in the stacked direction (stacked closer to 0.05 or the same size at narrower width). If C1 to C3 hold but no cell shows a difference, stacking is justified on correctness alone: make it the default and say in NEWS that intervals may move either way and are not systematically narrower or wider.
- *Stacked stays opt-in for that weight form* if C2 or C3 fails (it is worse than today), or if C1 fails while *known* satisfies C1.
- *Both fail C1* in some cell: neither is validated there; document the cell, make no default change, and treat as a finding about the weight model rather than the variance.
- Trimmed weights failing C1 only: refuse stacking when `weight_trim < 1` (note section 4.1, option 3), keep known-weights SEs for them.

## 4. Controls

1. **Reproduces the shipped path.** On 50 replications per DGM, the harness's *known* interval from `dop` equals `infer(type = "mc")` of the actual `run()` -> `pool()` result, endpoints within 0.01 (Monte-Carlo noise of the shipped interval is about 0.003). If not, the harness is not testing what users get; stop.
2. **Can the grid see a wrong variance?** A *control arm* uses the model-based covariance (`se_type = "model"`, documented as invalid under weighting) on the unstabilized joint weights. It must show size above 0.065 or below 0.035 in at least one `aux` or `auxm` cell. If it does not, the grid cannot detect variance errors of that kind and its clean results for the other arms do not count.
3. **Known-answer for the arms:** at 20 replications the stacked variance of the first 3 draws equals a bootstrap oracle within the bar already used in `dev/ipw-stack-oracle.R` (ratio in [0.90, 1.10]); guards against a harness-side plumbing bug.

## 5. Commands and structure

```bash
# pilot on the laptop (one cell, 20 reps)
Rscript dev/sim-ipw-stack-smoke.R
# hopper pilot: ONLY_CELLS=1,40 REPS=20 sbatch --array=1-8 dev/sim-ipw-stack.sbatch
# hopper full: 48 cells x 4 chunks = 192 tasks
sbatch --array=1-192%40 dev/sim-ipw-stack.sbatch
Rscript dev/sim-ipw-stack-combine.R ~/projects/missingmed_sim/out-ipw
Rscript -e 'devtools::test(filter = "ipw-stack")'
```

| Path | Role |
|---|---|
| `dev/sim-ipw-stack-lib.R` | `ipw_cells()`, `gen_ipw()` (with truth check), `one_ipw(cell, seed)` returning, per weight form, estimates, both `a*b` intervals, widths, failure flags |
| `dev/sim-ipw-stack-hopper.R`, `dev/sim-ipw-stack.sbatch` | one array task = one chunk of one cell, as `dev/sim-glm-mbco-*` |
| `dev/sim-ipw-stack-combine.R` | criteria C1-C5, controls, decision table |
| `dev/sim-ipw-stack-smoke.R` | laptop pilot plus controls 1 and 3 |
| `docs/specs/RESULTS-ipw-stack-coverage-2026-10-09.txt` | raw combine output, committed |

Hopper uses the same recipe as the glm gate (`source /etc/profile.d/modules.sh; module load r/4.4.0-ytj2`, `~/Rlib-sem`, account 2016507); install the `dev` build of missingmed there first (it must contain `.ipw_stacked_vcov()`; `dev` does as of `1710104`).

Code style: match `dev/sim-glm-mbco-lib.R` (base R, `one_*` returns a one-row data frame per replication, seeds `5000 + rep`).

## 6. Tasks

1. `ipw_cells()` and `gen_ipw()` with the truth check; laptop test that the 48 cell definitions are stable (stored-definition comparison, as for the glm gate).
2. `one_ipw()` with all weight forms and the control arm; smoke on one cell, controls 1 and 3 pass.
3. Hopper scripts and a pilot (2 cells, 20 replications) via `sbatch`; read the per-column failure shares before launching the full run.
4. Full run, `combine`, write section 8 (results) here with the decision table; commit `RESULTS-*.txt`.
5. Only then: note step 4 (wire into `run()`, the `weights_known` argument, docs, NEWS), per the decision.

Each task ends with its own check before the next starts.

## 7. Boundaries

- **Always:** fix the criteria in this file before any run; report failure shares per column; use paired comparisons; run on hopper through `sbatch`; stage explicit paths (memory `codex-drops-agents-md-in-worktrees`).
- **Ask first:** changing a criterion or a cell after seeing results (record it as an addendum with the reason); adding weight forms or a misspecified-missingness arm; touching medfit or RMediation; changing the default `weights_known` before the decision table exists.
- **Never:** run the grid on the laptop beyond the pilot; read a size from a column with more than 1% dropped replications as unconditional; claim narrower or wider intervals in NEWS without the paired width comparison.

## 8. Not in scope

lavaan IPW; wrong missingness models; non-glm families beyond Gaussian (the weight-score algebra is family-independent, the harness is not, so binary outcomes are a follow-up cell block); MBCO for IPW (refused today); small `n` below 200.

## 9. Risks

- **The difference may be too small to see.** The bootstrap oracle already showed marginal SEs move by 1-4%. The paired design and 2000 replications are the response; if C4 shows nothing, the rule above justifies stacking on correctness alone.
- **`auxm` truth.** Closed-form truth is checked numerically per cell; a failed check stops the run.
- **Trimming** is the approximate case; the oracle's one failure was there. A C1 failure for that weight form has a defined consequence.
- **Positive definiteness of the stacked 2x2 block** is not guaranteed in small samples; C5 counts it.

## 10. Questions and decisions (2026-10-09)

Adopted as recommended on the author's blanket approval; change any of them before the full run and record it here.

1. **Replications: 2000 per cell (recommended)** — ADOPTED versus 1000 as in the glm gate. Cost difference is negligible; the extra precision is what makes the paired comparison informative.
2. **Include `auxm` (recommended).** ADOPTED. It is the only DGM where the shared-weight `cov(a, b)` is large. Drop it only if you want a smaller grid.
3. ADOPTED as written. **Decision threshold for "stacked becomes the default":** as written (C1-C3 everywhere; a difference is not required). The stricter alternative requires a significant benefit before changing any default.
4. **Binary outcome block:** ADOPTED, after the Gaussian decision.

## 11. Addendum A (2026-10-09, during T2 and T3, before any hopper result)

Two flaws in the approved spec were found while building the harness. Both are recorded here before any grid result exists; neither uses a result to choose a criterion.

**A1. A third arm, `known_hc0`.** medfit's sandwich is HC3 (`sandwich::vcovHC` default); the stacked estimator is HC0-type. Comparing them directly confounds estimating the weights with the small-sample leverage correction. Measured on the laptop, T2 control run (stabilized joint weights): the HC0 and shipped HC3 interval endpoints differ by up to 0.07 at n = 500 and 25% missing, and up to 0.47 at n = 200 and 40% missing. Every replication therefore also reports `known_hc0` (block-diagonal, HC0, the stacked code with the weight-score blocks removed). Reading: *stacked vs `known_hc0`* is the effect of estimating the weights and of `cov(a, b)`; *`known_hc0` vs `known_hc3`* is the small-sample correction. Criteria C1-C3 stay as written, against `known_hc3` (what users get today). If stacked fails C1 only where `known_hc0` also fails, the cause is the missing small-sample correction, not the weight-score term, and the follow-up is an HC-corrected stacked variance, not rejecting stacking.

**A2. The C1 bar.** C1 as approved (size <= 0.060, coverage >= 0.940) sits two Monte-Carlo se from 0.05 at 2000 replications (se 0.0049). With about 27 null cells per weight form, a perfectly calibrated estimator would fail it by chance more often than not. C1 is now **size <= 0.065 and coverage >= 0.935** (about 3 se; the chance a calibrated estimator exceeds it in a given cell is 0.1%, about 3% per weight form over its null cells). Pre-registered consequence: a weight form whose only C1 exceedances are cells with size in (0.065, 0.070] is rerun in those cells with 10000 replications before the decision; the rerun decides. C2 and C3 (paired, tolerance 0.010) are unchanged.

**A3. Control 1 bar.** The shipped Monte-Carlo interval's noise grows with width, so the bar is 0.01 + 0.02 x width per endpoint, not a flat 0.01. Control 1 has a positive control: `known_hc0` must exceed the same bar somewhere (it does, by 0.69), so the control can tell a wrong covariance from the shipped one.

**A4. `combine` refuses to present a partial run as a decision.** It prints "INCOMPLETE RUN ... Decisions below are NOT valid" unless all 48 cells have at least 2000 replications.

## 12. T4 hopper pilot (2026-10-09)

Install: `dev` tip `ec51884` (contains `.ipw_stacked_vcov()` and the #70 guard) built with `R CMD build --no-build-vignettes`, installed to `~/Rlib-sem` by batch job 4334215 (previous install backed up to `~/Rlib-backup/missingmed-before-ec51884`). Pilot: job 4334216, `ONLY_CELLS=1,40 REPS=20`, 8 array tasks (cell 1 = `std`, n = 200, 25% missing, P1; cell 40 = `auxm`, n = 200, 40% missing, P4), all COMPLETED, 0.7 to 0.8 s per task.

Failure shares (520 rows = 40 replications x 13 arm-form rows): error rows 0, NA intervals 0, non-positive-definite stacked blocks 0, refused or non-converged fits 0; the trimmed form trimmed 5.2 rows per replication on average. No column is near the 1% bar. This is a plumbing check: 20 replications cannot show a rare failure below about 5%, so `combine` on the full run is what reads C5. Throughput is about 0.16 s per replication, so the 192-task full run is about 80 s per task.
