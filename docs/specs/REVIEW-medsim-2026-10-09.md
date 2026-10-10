# REVIEW: medsim against missingmed and medfit (2026-10-09)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Scope** | `~/projects/r-packages/active/medsim` (0.5.1.9000, branch `dev`, `d7b9b75`), read-only. Compared with missingmed 0.8.0.9000 (`dev`) and medfit 0.6.0 (`dev`). Nothing in medsim, medfit or the manuscript was edited. |
| **Why** | Author request: "review medsim and make recommendations based on missingmed and medfit latest interactions". Triggered by the glm and Gaussian calibration results of the same day ([SPEC-glm-mbco-calibration-2026-10-09.md](SPEC-glm-mbco-calibration-2026-10-09.md) sections 8-10). |
| **Audience** | The medsim session and the Missing Effect manuscript session. Each owns its repo; these are recommendations, not changes. |

## 1. How the three packages interact today

| Pair | Interaction |
|---|---|
| medsim and missingmed | **None in code.** medsim carries its own D4-MBCO (`R/methods_missing.R:336-440`), ported from the manuscript prototype `Missing Effect/code/prototype-d4-mbco.R`. missingmed ported the same prototype (`R/mbco_mi.R`). Two implementations of one procedure. |
| medsim and medfit | **None in code.** medfit is in `Suggests` (`>= 0.2.0`) and appears only in a dependency listing (`R/cluster.R:1028`). medfit 0.6.0 (cluster 2-1-1 design, `engine = "lmer"`) and the planned native SEM engine do not touch medsim. |
| missingmed and medfit | missingmed delegates fitting to `medfit::fit_mediation()` and `extract_mediation()` (IPW weights, `se_type = "sandwich"`, lavaan). |

So the only live coupling is the **drift risk between two copies of D4**. That is where this review finds problems.

## 2. Evidence: the two implementations agree except where they should not

Run 2026-10-09 (script in the session scratchpad; `medsim` loaded with `pkgload::load_all` from its `dev` tree, which left `git status` clean). 12 incomplete Gaussian datasets (n = 200, 40% missing in `M` and `Y`, `mice` m = 20), the same imputed lists through `medsim:::.medsim_d4_mbco()` and `missingmed::mbco_d4()`, `ariv` own and fixed:

| Quantity | Result over 24 comparisons |
|---|---|
| `D4` | max absolute difference **3.3e-12** |
| `r4` | max absolute difference **1.0e-12** |
| stacked branch | identical in all |
| `nu` | medsim's is smaller in all (e.g. 83.6 vs 114.6; 54.4 vs 70.8) |
| `p` | medsim's is larger in all, by a ratio of **1.000 to 1.063** (e.g. 0.00856 vs 0.00805) |

The procedure (statistic, `r4`, branch choice, `own` and `fixed`) is the same. The denominator df differs, as found in item D.

## 3. Recommendations

Ordered by what they protect. "Effort" is for the owning session.

### R1. Align the D4 denominator df (medsim; effort XS code, S tests)

- **Where:** `R/methods_missing.R:387-392` (`.medsim_d4_from_stats`) uses the Li et al. (1991) df. Chan and Meng (2022, arXiv:1711.08822, Algorithm 2, eq. 2.15) and `mitml::testModels(method = "D4")` use `nu = k (K - 1) (1 + 1 / r4)^2`. missingmed switched in #62.
- **Effect:** medsim's p-values are slightly conservative against the published procedure (ratio up to 1.063 above; size gap at most about 0.002 at K = 20).
- **Why the test did not catch it:** `tests/testthat/test-methods-missing.R:105-135` compares to `mitml` with tolerance 1e-3 on `F` and a **relative 10% on p**, and explains the p gap as "stochastic variation in `mice` imputations". Both sides use the **same** imputations (`il`); the gap is the df formula, which is deterministic. Tighten to about 1e-8 on `D4`, `r4`, `nu` and `p`, and the formula fix makes it pass. missingmed's `tests/testthat/test-mbco-df.R` is a template (`mitml` parity for k = 1 and 2).
- **Docs:** `R/methods_missing.R:31` says "exact match vs `mitml::testModels(method = "D4")`". True for `D4` and `r4` only until R1 lands.
- **Consequence for completed grids:** p-values already stored change in the third digit under the fix. If the stored columns include `D4`, `k` and `r4`, `p` can be recomputed (`pf(D4, k, k * (K - 1) * (1 + 1 / r4)^2, lower.tail = FALSE)`) without rerunning; otherwise leave them and state the conservative direction.

### R2. Reconsider the default `ariv = "own"` (medsim default; manuscript choice of column) (effort S)

- **Evidence** (spec section 10; hopper job 4334091, 20 cells x 1000 replications, plain Gaussian, k = 1 on both branches, the model medsim fits): `"fixed"` has size **at most 0.047** in all cells; `"own"` reaches **0.083** (n = 200, 40% missing, null a = 0), 0.075 (n = 200, 40%, b = 0) and 0.069 (n = 500, 40%, a = .1). The excess grows with missingness and shrinks with n. `"own"` returned a p-value in every replication, so these sizes are unconditional.
- **Good news:** medsim already emits **both** `indirect_p` (own) and `indirect_p_fixed` plus `branch_mix`, `p_branch_a`, `stacked_branch`, `r4`, `r4_fixed` (`R/methods_missing.R:11-21`), and `Missing Effect/code/summarize-fixed-branch.R` and `summarize-fixed-branch-power.R` exist. For grids already run with these columns, reporting the fixed column needs **no rerun**.
- **Recommend:** (a) medsim: make `"fixed"` the default in the next minor with a NEWS entry, or at least document the liberality in `?medsim_method_mbco_mi`; (b) manuscript: report `indirect_p_fixed` as the primary test and `own` as the comparison, citing the calibration; (c) before either, **verify which column the current manuscript tables use** (not checked in this review).
- missingmed's default is already `"fixed"`; its docs are being updated to say `"own"` can be liberal.

### R3. Keep the two D4 copies from drifting again (medsim; effort S)

- Add a cross-implementation test in medsim: `skip_if_not_installed("missingmed")`, then the comparison of section 2 (D4, `r4`, branch, `nu`, `p`) on a fixed seed. It would have caught R1 on the day missingmed changed.
- Alternative, larger: let `medsim_method_mbco_mi()` delegate to the exported `missingmed::mbco_d4()` (it takes a plain list of data frames) behind an option, keeping the native path for bit-for-bit reproduction of old grids. Gain: glm families, convergence refusal, lavaan, and every future fix. Cost: a missingmed dependency (it is on r-universe, not CRAN) and a speed check (medsim's version shares one stacked fit and uses `lm`).

### R4. Non-Gaussian and `X:M` scenarios need missingmed's engine, not medsim's (medsim; effort M if wanted)

- `.medsim_mbco_ll()` fits `lm` and assumes k = 1 on both branches (`k = 1` is hard-coded in `.medsim_d4_mbco`, `R/methods_missing.R:~430`). A binary or count outcome, or an `X:M` outcome model (k = 2 on one branch), is outside what medsim computes.
- missingmed's glm MBCO is now calibrated for those cases (`"fixed"` size at most 0.057 over 132 cells, all families; spec section 8). If the manuscript or a follow-up paper needs such scenarios, route them through `missingmed::mbco_d4()` (R3, alternative) instead of extending the `lm` path.

### R5. The IPW arm uses model-based standard errors (medsim; effort S; robustness appendix only)

- `medsim_method_ipw()` fits `lm(weights = )` and takes the model-based SEs (`R/methods_missing.R:299-321`), then a Sobel-type SE `sqrt(b^2 va + a^2 vb)` with a normal p (`:290-292`). The ipw article in missingmed states that model-based SEs are "wrong for weighted fits"; missingmed and medfit use the HC3 sandwich (`se_type = "sandwich"`).
- Recommend `sandwich::vcovHC(type = "HC3")` for `a` and `b`, or label the arm "naive weights-as-known SE" wherever it is reported. Both treat the weights as known; propagating weight-estimation uncertainty is missingmed plan item E.
- The weight model is `r ~ X + C` (`:233-236`), which omits `M` and `Y`; whether that matches the missingness mechanisms of medsim's DGMs was not checked. The arm is a comparator, as its docstring says.

### R6. medfit: nothing to do, one stale floor (medsim; effort XS)

- medfit 0.6.0 and the native SEM plan do not affect medsim. Do not add a medfit dependency for them.
- `Suggests: medfit (>= 0.2.0)` is stale: nothing in `R/` calls medfit. Drop it, or raise the floor to match what the rest of the ecosystem needs (missingmed needs `>= 0.3.1`).

### R7. Stale statements in the manuscript's own docs (manuscript session; effort XS)

- `Missing Effect/CLAUDE.md` still lists missingmed as "RELEASED v0.5.0"; current is 0.8.0 (0.7.0 deleted the S4 stubs, 0.8.0 added lavaan MBCO). It also calls medsim "the production estimator": that remains true, but the calibration evidence above now exists only for `"fixed"`.

## 4. What this review did not check

- Which `indirect_p` column the manuscript tables and figures use today, and whether any shipped grid lacks the `fixed` columns.
- Speed of delegating to `missingmed::mbco_d4()` (R3, alternative).
- medsim's amputation designs against the MAR logistic mechanism used in the missingmed calibration (the DGMs differ; a medsim cell outside the calibrated range, for example more than 40% missing, has no size evidence).
- Anything in medfit beyond its NEWS and version (no code reading).

## 5. Ready-to-send messages

**To the medsim session:** "missingmed 0.8.0.9000 (#62) switched the D4 denominator df to Chan and Meng eq. 2.15, `k (K - 1) (1 + 1 / r4)^2`, as `mitml` does. medsim still uses the Li et al. df (`R/methods_missing.R:387-392`): `D4` and `r4` match missingmed to 3e-12 and the branch is identical, but `nu` is smaller and `p` up to 6.3% larger. The parity test at `tests/testthat/test-methods-missing.R:105-135` has a 10% relative tolerance on p that hid it. Also: on a plain Gaussian k = 1 model, `ariv = "own"` has size up to 0.083 at n = 200 and 40% missing; `"fixed"` stays at or below 0.047. Details: missingmed `docs/specs/REVIEW-medsim-2026-10-09.md` (R1-R6)."

**To the manuscript session:** "On the model medsim fits (Gaussian, k = 1), `ariv = 'own'` is liberal at about 40% missing and n of about 200 (size 0.083); `'fixed'` is calibrated (at most 0.047 over 20 cells). medsim already emits `indirect_p_fixed`, so the fixed column can be reported without a rerun for grids that recorded it. Please check which column the tables use. Details: missingmed `docs/specs/REVIEW-medsim-2026-10-09.md` (R2, R7)."
