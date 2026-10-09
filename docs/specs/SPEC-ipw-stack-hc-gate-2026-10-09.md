# SPEC: second coverage gate for the stacked IPW variance (HC-corrected, correct DGMs)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | APPROVED 2026-10-09 ("do all"): approved as written with the recommended answers to section 10 (variants as declared; F7 revisited after the results; limited-scope claim for trimmed fits). |
| **Plan** | [PLAN-ipw-stack-hc-2026-10-09.md](PLAN-ipw-stack-hc-2026-10-09.md), task T1; the author accepted the plan's recommended defaults ("as recommended") |
| **Follows** | first gate: [SPEC-ipw-stack-coverage-2026-10-09.md](SPEC-ipw-stack-coverage-2026-10-09.md) sections 13 and 14 (results, bias explanation) |
| **Decision it serves** | Whether any HC-corrected stacked variance is *viable* for `method = "ipw"`, per weight form. Viability only authorizes planning the wiring (plan T8); it does not enable anything. |

## 1. Assumptions (correct me now)

1. **What changed since the first gate:** the stacked variance gains `HC3` (primary) and `HC1` (secondary) variants (plan T2); the DGMs are redesigned so each weight form is judged only where its missingness model is correctly specified; weight diagnostics are recorded; truth is the stored population value; seeds are cell-specific.
2. **Variants are declared here, before any result:** `stacked_hc3` (influence of a complete case scaled by `1 / (1 - h_i)`, the variance carries the square as in `sandwich`), `stacked_hc1` (each regression's columns scaled by `sqrt(n_cc / (n_cc - p_r))`), and `stacked_hc0` (the first gate's estimator, kept as a reference arm). No variant is added after seeing results.
3. **The weight-score term is not leverage-corrected** (only the regression-score term is). If the primary variant under-covers in `aux` cells, a missingness-model-leverage variant is a recorded follow-up, not an arm of this gate.
4. **The cap of trimmed weights is not re-estimated** in the variance (constant-cap approximation, note section 4.1). Per the Codex review of the plan, the quantile cap is an estimated quantity the approximation ignores, so **no claim about trimmed fits goes beyond the tested scope** (section 7).
5. **glm engine, Gaussian outcome, `a*b` interval by the distribution of the product (`"dop"`)**, as in the first gate. lavaan, binary outcomes and misspecified missingness models are out of scope.
6. **hopper runs it**; the laptop only runs the unit tests, controls and a pilot.
7. **F7 (the default joint missingness model) stays "keep and document" for now** (author's recommended default), but see section 7: wiring is blocked on revisiting it.

## 2. Objective and design

**Objective.** Determine, for each weight form, whether an HC-corrected stacked variance gives intervals for `a*b` that are valid (section 3) and not worse than today's known-weights HC3 path, in the cells where that form's missingness model is correct; and report diagnostics that separate variance error from point-estimate bias.

**DGMs.** `X`, `C`, `Z` as before. `M = aX + 0.3C + zm Z + e`, `Y = b_s M + 0.2X + 0.3C + zy Z + e`, with `b_s = b - zy zm / (1 + zm^2)` so the complete-data population `a`, `b` equal the nominal values (verified numerically per cell).

| DGM | `zm` | `zy` | Missingness logit slopes (`X`, `C`, `Z`) | Mechanism | Decisive forms |
|---|---|---|---|---|---|
| `std` | 0 | 0 | .5, .5, 0 | M and Y missing **independently** | `spv` |
| `aux` | 0 | .7 | 0, 0, 1 | independent | `spv` |
| `auxm` | .7 | .7 | 0, 0, 1 | independent | `spv` |
| `stdj` | 0 | 0 | .5, .5, 0 | M and Y missing **together** (one Bernoulli per row) | `uj`, `sj`, `sjt` |
| `auxj` | 0 | .7 | 0, 0, 1 | together | `uj`, `sj`, `sjt` |
| `auxmj` | .7 | .7 | 0, 0, 1 | together | `uj`, `sj`, `sjt` |

Why this split: under independent missingness P(both observed | z) is a product of logistics, so the joint (complete-case) model is misspecified and only `spv` is correct (spec 1, section 14: joint forms plateau at b = 0.278 at n = 1e5). Under simultaneous missingness P(both observed | z) is one logistic, so the joint forms are correct and `spv` is not (it multiplies the same indicator twice). A form's results in a cell where it is misspecified are reported and never decide.

**Cells.** 6 DGM x n {200, 500} x missing share {0.25, 0.40} per variable x point {P1 (a, b) = (0, .3); P2 (.3, 0); P3 (0, 0); P4 (.3, .3)} = **96 cells x 2000 replications**, 4 chunks per cell = 384 tasks. Intercepts are solved once per DGM and rate so each of M and Y has the stated marginal missing share.

**Arms per replication** (same data, four weight forms `uj`, `sj`, `sjt` (`weight_trim = 0.95`), `spv`; all missingness models contain every driver): `known_hc3` (today's behavior), `known_hc0`, `stacked_hc0`, `stacked_hc1`, `stacked_hc3`, plus the control arm `model_se` (unstabilized joint only). Every replication also records the effective sample size `(sum w)^2 / sum w^2`, the largest weight's share, and the trimmed share.

**Truth and seeds.** Truth is the stored population `a*b` per (DGM, point) from a 2e6-row complete-data regression (not the nominal product). Seeds are `5000 + 100000 * cell + rep`.

## 3. Pass criteria (fixed before the run)

Evaluated per weight form, on **decisive cells only** (section 2), against `known_hc3`. Bars as in the first gate's Addendum A2 (size <= 0.065, coverage >= 0.935, about 3 Monte-Carlo se at 2000 replications; paired tolerance 0.010).

| # | Criterion |
|---|---|
| C1 | **Validity:** stacked size <= 0.065 at P1-P3 and coverage >= 0.935 at P4 |
| C1* | **Validity net of bias:** in every decisive cell either C1 holds, **or** `known_hc3` also fails C1 there (a *bias-limited* cell) **and** stacked is within 0.010 of `known_hc3`. Bias-limited cells are listed with the mean bias of `a`, `b`, `a*b` and the effective sample size |
| C2 | **Not worse than today:** stacked size <= `known_hc3` size + 0.010 and stacked P4 coverage >= `known_hc3` coverage - 0.010, per cell |
| C3 | **Power:** stacked rejection at P4 >= `known_hc3` rejection - 0.010, per cell |
| C4 | **Paired detail** (informational): discordant counts and exact McNemar p-value per cell, median width ratio stacked/`known_hc3`; `stacked_hc0` and `known_hc0` reported for attribution |
| C5 | **Failure shares per column:** refused or non-converged fits, non-positive-definite stacked blocks, leverage-one cases (`1 - h_i <= 0`), NA intervals; a size from an arm with more than 1% dropped replications is marked conditional |
| C6 | **Bias and effective sample size by cell** (informational), with the dose of weight concentration, so a failure can be read as variance error or point-estimate bias |

**Variant rule (per weight form).** `stacked_hc3` is *viable* if C1*, C2 and C3 hold in every decisive cell and C5 shows no conditional decisive cell. If it is not, `stacked_hc1` is viable on the same terms. If neither is, no stacked variance is viable for that form (the finding is recorded with its cells; a leverage-corrected weight-score term is the named follow-up). No variant is chosen outside this rule.

**What each outcome authorizes.** *Viable* means "plan the wiring for the tested scope", not "enable it" (section 7). *Not viable* closes plan item E for that form: stacking stays internal and documented.

## 4. Controls

1. **Reproduces the shipped path:** `known_hc3` equals `infer(type = "mc")` of the real `run() -> pool()` result within 0.01 + 0.02 x width per endpoint (first gate, control 1), with the positive control that `known_hc0` must exceed the same bar.
2. **The grid can see a wrong variance:** `model_se` must show size above 0.065 or below 0.035 in at least one `aux`/`auxm`/`auxj`/`auxmj` null cell; otherwise clean results do not count.
3. **Known answer for the new variants (precondition, plan T2):** with the weight-score blocks removed, `hc = "HC3"` equals `sandwich::vcovHC(type = "HC3")` and `"HC1"` equals type `"HC1"` per regression to 1e-8, and the planted exponent error (`1 / (1 - h_i)^2` on the influence) fails that test.
4. **Bootstrap oracle:** stacked SE versus a bootstrap of the whole pipeline (B = 500) on 3 draws per DGM: `stacked_hc0` within [0.90, 1.10]; `stacked_hc3` reported (expected larger by the leverage factor). *Recorded during T3 (before any grid result):* B was first set to 300, which fails the bar by noise alone (the relative se of a bootstrap SD is about 1 / sqrt(2B), so 36 comparisons at B = 300 reach about 0.11 in log ratio); at B = 500 the ratios are 0.927 to 1.073 with no pattern by DGM, and the mean log ratio is -0.011 for `a` and -0.034 for `b` (the HC0 small-sample underestimate the HC variants target).
5. **The specification split is real (large-n control):** at n = 1e5 the joint forms recover `b` within 0.01 on `stdj`/`auxj`/`auxmj`, `spv` does on `std`/`aux`/`auxm`, and the joint forms fail to on `auxm` (b near 0.278) so the control can fail. This is the section 14 script, run as a harness test.

## 5. Commands and structure

```bash
Rscript dev/sim-ipw-stack-smoke.R --defs --controls      # laptop: definitions, truth, controls 1, 4, 5
Rscript -e 'devtools::test(filter = "ipw-stack")'        # T2 anchors, control 3
# hopper pilot: ONLY_CELLS=1,60 REPS=20 sbatch --array=1-8 dev/sim-ipw-stack.sbatch
# hopper full: 96 cells x 4 chunks
sbatch --array=1-384%40 dev/sim-ipw-stack.sbatch
Rscript dev/sim-ipw-stack-combine.R ~/projects/missingmed_sim/out-ipw2
```

Files as in the first gate (`dev/sim-ipw-stack-{lib,smoke,hopper,combine}.R`, `dev/sim-ipw-stack.sbatch`, stored cells), updated in place on a feature branch; `R/ipw_stack.R` and `tests/testthat/test-ipw-stack.R` for the variants. Results to `docs/specs/RESULTS-ipw-stack-hc-gate-2026-10-09.txt`. Code style matches `dev/sim-glm-mbco-lib.R` (base R, one row per replication and arm).

## 6. Testing strategy

Test-first for the variants (plan T2): anchors (control 3), the existing brute-force equalities for `HC0`, a leverage-one error test. The harness is tested by definitions (96 cells, truth within 0.005, missing shares within 0.02, stored definitions identical in a **fresh** process, planted defect caught), the controls above, and a `combine` selftest with planted outcomes: primary viable -> adopted; primary fails, secondary viable -> secondary; both fail -> none; a failure in a non-decisive cell does not decide; a bias-limited cell is labelled, not blamed; an all-dropped cell fails instead of crashing.

## 7. Boundaries

- **Always:** fix criteria here before any run; judge a form only on its decisive cells; report C5 and C6 next to every size; use paired comparisons; run on hopper through `sbatch`; stage explicit paths.
- **Ask first:** changing a criterion, a cell, a variant or the decisive-cell table after seeing results (record as an addendum with the reason); touching medfit or RMediation; any `run()`/`set_md_mediation()` change.
- **Never:** wire a stacked variance into `run()` on the strength of this gate alone; claim trimmed-fit (`sjt`) inference beyond the tested scope (`weight_trim = 0.95`, constant-cap approximation, these cells); read a size from a conditional arm as unconditional; add a variant after seeing results.
- **Wiring is blocked on two things beyond viability.** (a) **F7:** a stacked variance over the joint default would ship better-calibrated standard errors around a point estimate that is biased at any n when missingness is variable-specific (plan F7, spec 1 section 14). The Codex review of the plan recommends resolving the default (per-variable default, or an explicit opt-in with a warning) before wiring; the author's current choice is "keep and document", so wiring is **not** planned until F7 is revisited with this gate's results in hand. (b) **Trimming:** viability for `sjt` limits any user-facing claim to the tested scope, or requires a variance that includes the cap's estimation (bootstrap or influence of the quantile), neither of which this gate tests.

## 8. Success criteria

1. All controls pass and are reported first.
2. Every criterion in section 3 has a PASS/FAIL line per form and arm, on decisive cells only, with C5 and C6 beside it.
3. The decision table states, per weight form, "viable: hc3", "viable: hc1" or "none", with the cells behind any "none".
4. Results, raw output and the attribution script are committed; `.STATUS` updated.

## 9. References (cited by the Codex review of the plan; not read in this session, to be checked before any is quoted in documentation)

- Robins, Rotnitzky, Zhao (1994), *J. Am. Stat. Assoc.* 89, doi:10.1080/01621459.1994.10476818: IPW estimating equations for missing data with a correctly modeled observation probability; basis for accounting for estimated weights.
- Lunceford, Davidian (2004), *Stat. Med.* 23, doi:10.1002/sim.1903: variance implications of estimated propensity weights.
- Yang, Ding (2018), arXiv:1704.00666: design-stage uncertainty when trimming estimated propensity scores; motivates the trimmed-fit limit in section 7.

## 10. Open questions for the author

1. **Approve as written (recommended)**, including the variants (`hc3` primary, `hc1` secondary), the decisive-cell split, C1* (a bias-limited cell does not count against stacked only if stacked is within 0.010 of the shipped path), and 2000 replications.
2. **F7 timing:** revisit the default joint model **after this gate's results** (recommended; the results show how much a corrected variance matters next to the bias), versus resolving it before running the gate. The gate does not depend on it.
3. **Trimmed fits:** keep the limited-scope claim (recommended), or add a bootstrap arm that re-estimates the cap on a subset of cells (costly: about 500 refits per replication).
