# SPEC: the default missingness model for `method = "ipw"` (plan item F7)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | APPROVED 2026-10-09 ("approved"): all five recommended answers to section 10 (gate first; sequential default if the gate passes; no new argument, named list = sequence in list order; T0 docs PR now; ascending-missing-share order). Nothing in `R/` changes until the gate (T1-T4) has run. |
| **Origin** | [PLAN-ipw-stack-hc-2026-10-09.md](PLAN-ipw-stack-hc-2026-10-09.md) F7; the Codex adversarial review of that plan (high: "known joint-model bias remains the default behavior"); the second gate ([SPEC-ipw-stack-hc-gate-2026-10-09.md](SPEC-ipw-stack-hc-gate-2026-10-09.md) section 11) |
| **Evidence so far** | [SPEC-ipw-stack-coverage-2026-10-09.md](SPEC-ipw-stack-coverage-2026-10-09.md) section 14; [RESULTS-ipw-f7-pilot-2026-10-09.txt](RESULTS-ipw-f7-pilot-2026-10-09.txt) (laptop pilot, this spec) |
| **Decision it serves** | Which missingness model `weight_formula = NULL` fits, and what a named list means. Unlike the variance work, this changes users' **point estimates**. |

## 1. The problem

Complete-case IPW weights each complete row by 1 / P(all model variables observed | Z), with Z the fully observed predictors. The estimate is consistent only if that probability is modeled correctly. `R/ipw_run.R` offers two forms:

| Form | What it fits | Used when |
|---|---|---|
| **joint** | one logistic model for the complete-case indicator | `weight_formula = NULL` (default) or a single formula |
| **marginal per-variable** (`spv`) | one logistic model per incomplete variable, each on **all** rows; weight = 1 / product | `weight_formula` is a named list |

Each is right for one missingness structure and wrong for others, so neither can be the default on principle:

- **Independent** (M and Y missing separately given Z): P(both observed) is a product of two logistics. The joint model cannot represent it (biased at any n); the marginal product is correct.
- **Simultaneous** (M and Y missing together, e.g. one dropout event): P(both observed) equals each marginal, **not** their product. The joint model is correct; the marginal product double-counts and is biased.
- **Monotone** (Y observed only if M is): neither is correct.

The IPW article merged in #73 tells users the per-variable list is the fix. That is true only for the first structure, and the sentence needs the contrast (section 7).

## 2. Evidence

**Repo results (first gate, Addendum B).** `auxm`, 40% missing, true `b` = 0.30: joint `uj`/`sj` plateau at 0.278 at n = 1e5; marginal `spv` converges to 0.300 but is about -0.02 low at n = 200 to 500, gone by n about 5000.

**Laptop pilot (new; the script and output are in the RESULTS file).** Bias of the weighted complete-case `b` relative to the full-data `b` in the same replication, 60% observed, Z drives missingness. n = 1e5, 8 replications (se about 0.003):

| Mechanism | joint | marginal (`spv`) | **sequential** | sequential, reversed order | multinomial patterns |
|---|---|---|---|---|---|
| independent | -0.024 | +0.010 (se 0.008) | **-0.002** | -0.003 | -0.009 |
| simultaneous | -0.001 | **+0.051** | **+0.000** | -0.001 | errors (two patterns) |
| monotone (M then Y) | -0.014 | +0.032 | **+0.002** | **-0.021** | -0.018 |

*Sequential* is the chain rule: P(M obs | Z) x P(Y obs | M obs, Z), the second factor fitted only on rows where M is observed. It is an identity, so it is correct whenever each factor is logistic, whatever the dependence between the indicators. At n = 500 (300 replications) every form is 0.015 to 0.024 low in the independent mechanism, the finite-sample bias already documented.

What the pilot supports, and what it does not:

- **Supports:** the factorization, not the number of models, decides correctness; the chain rule is unbiased in all three mechanisms where its order matches the mechanism; order matters under monotone missingness (reversed: -0.021).
- **Does not support:** any claim about coverage, trimming, stabilization, a binary or lavaan outcome, or the grid's DGMs. Eight replications is a pilot; the gate in section 5 is what decides.

## 3. Literature

- Robins, Rotnitzky and Zhao (1994, [JASA 89:846](https://doi.org/10.1080/01621459.1994.10476818)): IPW estimating equations are unbiased under MAR with a correctly modeled observation probability and positivity.
- Seaman and White (2013, [SMMR 22(3):278](https://doi.org/10.1177/0962280210395740)): the standard review of IPW for missing data (choice of missingness model, truncation, stabilization, augmentation).
- Robins and Gill (1997, [Stat Med 16:39](https://onlinelibrary.wiley.com/doi/10.1002/(SICI)1097-0258(19970115)16:1%3C39::AID-SIM535%3E3.0.CO;2-D)): "randomized monotone missingness" as the general mechanism for non-monotone ignorable data; some ignorable mechanisms are not of that form.
- Sun and Tchetgen Tchetgen (2018, [JASA 113:369](https://doi.org/10.1080/01621459.2016.1256814)): IPW for non-monotone MAR has been held back by the lack of coherent missingness models; they propose a class of models and two estimators.
- Lunceford and Davidian (2004, [Stat Med 23:2937](https://doi.org/10.1002/sim.1903)): variance implications of estimated weights (the stacking work).

**Verification status.** I read the abstracts and search summaries, not the full texts. The chain-rule identity above needs no citation. Whether the sequential form is a special case of Robins and Gill's model class, and how Sun and Tchetgen Tchetgen's class relates to it, are **unverified**; read both before the documentation cites them (task T6).

## 4. Options

| | Option | Changes estimates? | Right under | Cost |
|---|---|---|---|---|
| A | Keep joint default, document (current) | no | simultaneous | none; leaves known bias in the default |
| B | A + a warning when more than one model variable is incomplete | no | simultaneous | XS; the warning fires for a structure the data cannot reveal, so it cannot say which form is right |
| C | Default to marginal per-variable | yes | independent | XS; swaps one wrong structure for another (+0.051 under simultaneous) |
| **D** | **Default to the sequential (chain-rule) form; named list = sequence in list order** | yes | independent, simultaneous, monotone (order permitting) | M: new fitting path, order rule, degenerate-factor handling, tests, docs |
| E | Multinomial pattern model | yes | independent only (pilot) | M; the pilot shows no gain over D |

## 5. Pre-registered gate (to choose between A/B and D with evidence)

Same harness as the earlier gates (`dev/sim-ipw-stack-*`, hopper array, per-column failure shares). Design, declared before any result:

- **Mechanisms:** independent, simultaneous, monotone (M then Y). The lib's `joint` flag becomes a `mech` field.
- **DGMs:** `std`, `aux`, `auxm` (as the second gate). Points P1, P2, P4. n = 200, 500, 5000. Missing share 0.25 and 0.40 for each of M and Y. 1000 replications per cell: 3 x 3 x 3 x 3 x 2 = 162 cells. (I estimate 15 to 30 minutes on hopper from the second gate's rate; unmeasured.)
- **Weight forms:** joint, marginal, **sequential in the default order** (ascending share of missing values, ties in model-variable order), sequential reversed (diagnostic only, not a candidate). Stabilized, untrimmed, `se_type = "sandwich"` (the shipped path).
- **Truth:** the population regression coefficients the lib already stores (24 truth rows); they depend on the DGM, not the mechanism.

| Criterion | Rule |
|---|---|
| **C1 consistency** | At n = 5000, \|mean bias in `b`\| is at most 0.010 for the sequential form in every cell. Marginal and joint are reported, not required to pass (that they fail somewhere is the finding). |
| **C2 coverage** | Shipped HC3 interval coverage of the indirect effect at n = 5000 is at least 0.93 for sequential in every cell. |
| **C3 non-inferiority** | At n = 200 and 500, sequential's coverage is no more than 0.01 below the joint default's in the **simultaneous** mechanism (where the status quo is correct), and its RMSE of `b` no more than 5% above. |
| **C4 failures** | At most 1% of replications per column refuse, fail to converge, or hit a degenerate factor; the count is printed per cell and column. |
| **C5 order** | Reported, not a pass criterion: bias of the reversed order under monotone missingness, to size the cost of a wrong order. |
| **Controls** | A planted-defect arm (marginal weights under simultaneous missingness) must fail C1 by more than 0.03; a known-weights arm (true P) must pass C1. A control that cannot fail voids the run. |

**Decision rule.** C1-C4 all pass: adopt D (section 6). C1 passes and C3 or C4 fails: keep the joint default, add warning B, and ship the sequential form as an explicit opt-in. C1 fails: no change to the default; record the result and stop. The rule is applied as written, as in the second gate.

## 6. Design if D is adopted

- **Default (`weight_formula = NULL`).** Each incomplete model variable V, in order, gets a logistic model for "V observed" fitted on rows where every earlier variable is observed, with the same default predictors as today (the fully observed model variables). Weight = 1 / product of the fitted probabilities; the stabilization numerator is the analogous product of treatment-only models.
- **Order.** Ascending share of missing values; ties in model-variable order. Under monotone dropout the earlier variable has fewer missing values, so the rule recovers the right order there (the pilot's mechanism). An unusual mechanism can still break it; C5 sizes that.
- **Named list.** The list's order is the sequence, each entry conditional on the earlier ones being observed. This changes what a list means today (marginal on all rows). The two agree when missingness is independent; they differ under simultaneous or monotone missingness, where the list was wrong. A NEWS entry states it.
- **Single formula.** Unchanged: one joint model with those predictors (explicit user choice).
- **Degenerate factor.** If V is observed on every row where the earlier variables are, its probability is 1: skip the fit and record it, rather than warn on a constant response (the simultaneous case). A factor with a constant response elsewhere stays an error.
- **Interaction with stacking.** `info$blocks` entries gain `rows` (the rows the model was fitted on). `.ipw_stacked_vcov()` is unwired and must be extended before any wiring; this spec does not do that.
- **No new argument.** Recommended; see question 3.

## 7. Documentation owed regardless of the decision

1. `vignettes/articles/ipw-weighting.Rmd` "One model or one per variable": state that the per-variable list is right for independent missingness and wrong for simultaneous missingness (+0.051 in the pilot), and that the joint default is right only for simultaneous missingness. This corrects an incomplete statement I merged in #73.
2. `?set_md_mediation` (`weight_formula`) and `technical.Rmd` to match.
3. `docs/specs/SPEC-ipw-stack-coverage-2026-10-09.md` section 14 consequence line: no change needed (it is scoped to the independent mechanism).

## 8. Tasks (each leaves the tree working; checkpoint after T4)

| # | Task | Acceptance | Verify |
|---|---|---|---|
| T0 | Docs correction (section 7), own PR | the contrast stated; counts and figures quoted from the RESULTS file | markdown lint; `devtools::document()` clean; CI |
| T1 | Extend `dev/sim-ipw-stack-lib.R`: `mech`, the sequential and reversed forms, per-column failure counts | selftest covers a planted marginal-under-simultaneous defect and a degenerate factor | `Rscript dev/sim-ipw-stack-smoke.R` and the combine selftest pass |
| T2 | Laptop smoke, then hopper pilot | 0 error rows; controls behave | pilot output quoted |
| T3 | Full grid on hopper (SLURM array, `~/Rlib-sem`, install via sbatch) | 162 cells complete; C4 counts printed | job state COMPLETED, row count |
| T4 | `combine` applies section 5 as written; results section appended here | decision stated | RESULTS file committed |
| T5 | If D: implement in `.ipw_weights_info()` (TDD), NEWS, man pages | known-answer test (weights equal the product of the conditional fits); planted-defect test (marginal fails under simultaneous at n = 2e4); degenerate-factor test; order test | full suite, counts quoted; `R CMD check` clean |
| T6 | If D: documentation per section 7 plus the literature check in section 3 | each claim matches a result | docs render; links resolve |

## 8a. Addendum A (T1, before any grid result): what the harness pilot changed

Written after the T1 harness and its 40-replication control pilot (`dev/sim-ipw-mech-smoke.R --controls 40`, n = 5000, 40% missing, P4, 26 s), before the grid has run. The pilot's mean bias in `b`:

| Mechanism / DGM | joint | marginal | sequential | reversed | true weights |
|---|---|---|---|---|---|
| independent / auxm | -0.023 | -0.001 | -0.002 | -0.002 | -0.000 |
| simultaneous / auxm | +0.001 | **+0.046** | +0.001 | +0.001 | +0.001 |
| monotone / auxm | -0.011 | +0.018 | +0.001 | -0.011 | +0.001 |

In `std` and `aux` every form is within 0.007 of zero in all three mechanisms: with no auxiliary variable acting on both M and Y, a wrong weight model does not move `b`. **Only `auxm` discriminates between forms.** The `std` and `aux` cells stay in the grid as no-harm cells for C2 to C4, and C1 is read in `auxm`.

Corrections to section 5, all declared now:

1. **Planted-defect bar.** "Fails C1 by more than 0.03" (bias above 0.04) is replaced by: in `sim` / `auxm` / P4 / 40% missing / n = 5000, the marginal form's absolute mean bias in `b` exceeds **0.03**. The pilot gave +0.046 with 40 replications, too close to 0.04 for a control that voids the run if it misses.
2. **Known-weights control.** The `true` arm (the DGM's own P(complete)) must have absolute mean bias in `b` at most 0.010 in every n = 5000 cell, or the run is void.
3. **C2 was incomplete in two ways.** (a) Scope: at P4 the bar is coverage of the indirect effect at least 0.93; at the null points P1 and P2 it is rejection of zero at most 0.065 (the earlier gates' size bar), since coverage of a near-zero truth is not the question there. (b) Escape clause, as in the earlier gates' C1*: a cell also passes if sequential is within 0.01 of the `true` arm in that cell (coverage not more than 0.01 lower, rejection not more than 0.01 higher), because the shipped variance's own limit is not what the default decision is about.
4. **A C2 failure alone** was unassigned in the decision rule. It follows the C3/C4 branch: keep the joint default, add warning B, ship the sequential form as opt-in.
5. **C3 scope.** All `sim` cells at n = 200 and 500 (the mechanism where the joint default is correct): at P4 coverage, at nulls rejection, each paired against the joint form's on the same replications; RMSE of `b` against the stored population `b` in every such cell.
6. **C4 failure** is a replication that errors, returns a non-converged model, or has no interval (non-positive-definite block). A degenerate factor (the second factor under simultaneous missingness) is expected, is not a failure, and is counted separately.
7. **Cost.** 0.07 s per replication at n = 5000, so the grid is about 2.5 core-hours (about 10 minutes on hopper at 40 concurrent tasks), below the 15 to 30 minutes estimated above.

## 9. Boundaries

- **Always:** pre-register before running; report failure shares per column; stage explicit paths; US spelling.
- **Ask first:** adding an argument to `set_md_mediation()`; adding a dependency (the pilot used `nnet` only for option E, which is not recommended, so none is needed); changing what a named list means.
- **Never:** change the default before the gate result; wire the stacked variance; edit medfit or RMediation; run the grid on the laptop.
- **Out of scope:** MNAR, missingness that depends on partially observed variables (the default predictors are the fully observed ones), doubly robust or augmented estimators, trimming and cap uncertainty, binary and lavaan outcomes.

## 10. Questions for the author (recommendation first)

1. **Gate before any change (recommended).** Run T1-T4, then apply the decision rule. The pilot has eight replications at n = 1e5; it justifies a gate, not a default change.
2. **Default if the gate passes: sequential (D).** It is the only form unbiased in all three pilot mechanisms. Alternatives: C swaps the failure mode, B only warns.
3. **API: no new argument; a named list means the sequence in list order (recommended).** Alternative: a `weight_model = c("sequential", "joint", "marginal")` argument, which keeps old lists reproducible but adds a knob whose right setting the user cannot determine from the data.
4. **T0 now, as a docs-only PR (recommended).** The correction to the article does not depend on the gate.
5. **Order rule: ascending missing share (recommended).** Alternative: model-variable order, simpler to explain, wrong for monotone dropout where the outcome is listed first in the formula.
