# SPEC: MBCO for the lavaan engine (`infer(type = "mbco")`)

| | |
|---|---|
| **Status** | ML IMPLEMENTED on `feature/mbco-provider` (T1-T6, T9) 2026-10-08, pending the ML calibration gate (T8a, section 11). MLR (T7, T8b) DEFERRED: refused until its own gate runs. Design amended after adverse review (S3 reversed to structural-only; section 10); S1-S10 grilled ([GRILL-sem-mbco-2026-10-08.md](GRILL-sem-mbco-2026-10-08.md)) |
| **Date** | 2026-10-08 |
| **Target** | 0.8.0 (feature; 0.7.0 shipped without it) |
| **Closes** | SPEC-s7-sem-engine-2026-09-23.md, Q4 ("MBCO for SEM gets its own spec") |
| **Evidence** | [probe-sem-mbco-2026-10-08.R](probe-sem-mbco-2026-10-08.R): 10/10 checks pass |
| **Affects** | `R/mbco_mi.R`, `R/infer.R`, `R/sensitivity_mnar.R`, new `R/mbco_lavaan.R`, `NEWS.md`, `vignettes/articles/lavaan-sem.Rmd`, tests |

## 1. Objective

`infer(type = "mbco")` on a lavaan fit refuses today (`R/infer.R`, Q4): the D4-stacked
MBCO engine refits with `glm()`, which is not the SEM. Make it work for the lavaan
engine, including a **latent mediator**, with the same statistic, the same
`MbcoMIResult`, and the same `ariv` options as the glm path.

Success means a user with `engine = "lavaan"` gets the Rubin-valid MBCO test of
H0: a·b = 0 that glm users already have, and on an observed-variable model it
**agrees with the glm engine to numerical precision**.

The test is a branch-union statistic, so at the intersection a = b = 0 it is
**conservative** (a minimum of two LRTs; prototype size 0.7% at a 5% level, n = 200,
m = 5). Validity there means size control, not exactness; the cost is power near the
intersection. This is documented, not hidden, and the ML calibration gate (section 5)
measures it.

## 2. What already works (evidence, not assumption)

The D4 machinery in `R/mbco_mi.R` is generic in one place only: it needs, per
dataset, the log-likelihood triple `(full, a = 0, b = 0)` and the number of
parameters `k` each null removes. Everything else (branch union
`T = 2 (ll_full − max(ll_a, ll_b))`, stacked fit, `d_S = T_stacked / K`, `r4`, `nu`,
the F reference, branch diagnostics) is estimator-free. The probe shows lavaan can
supply that triple:

| Check (observed model, n = 300; latent model, n = 400) | Result |
|---|---|
| lavaan triple vs the glm triple | equal to 1.8e-12 |
| branch-union T, lavaan vs glm | equal to 4e-12 |
| a = 0 LRT vs `lavaan::lavTestLRT()` | equal to 1e-8 |
| stacked T / K (K identical copies) vs single-dataset T | equal to 1e-9 (observed), 1e-6 (latent) |
| latent mediator: constrained fits vs `sem()` with `0*` syntax | exact (0.00e+00) |
| latent mediator: k on each branch | 1 (measurement model untouched) |

**A trap the spec must encode.** A constrained table built with a bare
`lavaan::lavaanify(model, auto = TRUE)` is not the table `sem()` fits: for a latent
model it has 16 free parameters where `sem()` has 14, and lavaan warns that the
information matrix cannot be inverted. The constrained fits must start from
`lavaan::parTable(<fitted full model>)`, which keeps every default `sem()` applied.

## 3. Decisions (S3, S4, S6, S7 and the release shape grilled 2026-10-08; the rest accepted as proposed)

| # | Question | Proposed decision | Alternative |
|---|---|---|---|
| S1 | How is `a = 0` / `b = 0` imposed? | Take `parTable()` of the **fitted full model**, set `free = 0` and `ustart = 0` on exactly one structural regression row, renumber `free`, refit with `lavaan()` on the same data. | `constraints = "a == 0"` (needs labels; users rarely supply them); editing the model syntax (brittle parsing) |
| S2 | Which rows are the a and b paths? | a: the row `mediator ~ treatment`; b: the row `outcome ~ mediator`. Not exactly one such row (none, duplicates, multi-group) is an error before any fit. A latent mediator uses its **structural** rows only; the measurement model and direct indicator effects stay free. | Constrain the indicators' loadings (changes the construct, not the path) |
| S3 | What does b = 0 mean with a latent mediator? | **Structural path only (amended 2026-10-08 after adverse review; reverses the grill ruling "path plus indicator links").** `b = 0` fixes the single row `Y ~ Ml`; loadings, measurement errors and any direct `Y ~ indicator` rows stay free, so k = 1 on both branches. Fixing the indicator links tests a larger hypothesis than a·b = 0: a model with b = 0 and a nonzero direct indicator effect satisfies the product null yet fails the expanded branch, so the test could reject a true H0. Direct `Y ~ indicator` rows are outside the tested path and are reported in the docs as such. | Path plus indicator links (grill ruling; would require redefining the hypothesis and calibrating that distinct test); drop the latent variable (not nested) |
| S4 | Estimators | **ML and MLR** (author's ruling, 2026-10-08). ML is the validated path. **MLR is experimental and gated** (Q6): it warns that its D4 pooling is unproven, and ships enabled only if the simulation gate in section 5 passes; otherwise it stays refused and moves to its own spec. `MLM`, `WLSMV`, `ordered`, `group`, `sampling_weights` and IPW are refused with a message naming the option. The refits reuse the stored `fit_args` (estimator, information, `std.lv`, ...) so every null fit is on the same footing as the full fit. | ML only (recommended, not chosen) |
| S5 | Non-convergence in a null fit | **Refuse**, naming the dataset (imputation k or "the stacked data") and which fit (`full`, `a = 0`, `b = 0`). Consistent with G2. | Treat as ll = −Inf (silently changes the branch) |
| S6 | Improper solution in a null fit (Heywood, `post.check` fails) | **Warn once**, naming the datasets, and proceed. Consistent with G2. | Refuse (fragile at m ≥ 20 with latent models) |
| S7 | API surface | `infer(type = "mbco")` and `sensitivity_mnar(type = "mbco")` work for lavaan, **and `mbco_d4()` gains `model =`** (author's ruling, 2026-10-08): `mbco_d4(implist, model =, treatment =, mediator =, outcome =, fit_args = list(), ariv =)`, with `formula_y`/`formula_m`/`family_*` mutually exclusive with `model`, mirroring `set_md_mediation()`. | Formula-only (recommended, not chosen) |
| S8 | Code shape | Refactor `.mm_d4_mbco()` to take a **log-likelihood provider** (`fits(data) -> c(full, a, b, k_a, k_b)`); the glm provider is the current code moved unchanged; add the lavaan provider in `R/mbco_lavaan.R`. | Duplicate the D4 pooling for lavaan (two engines to keep in sync) |
| S9 | `ariv` | Both `"fixed"` (default) and `"own"` work. With k = 1 on both branches `"own"` never refuses on branch disagreement. | Fixed only |
| S10 | Interaction terms | Out of scope: lavaan syntax has no product terms. A hand-made product column (`XM`) in `Y ~ M + X + XM` is **not** dropped by `b = 0`; documented, and the glm engine is the supported route for X:M. | Detect product columns heuristically (unreliable) |

## 4. Non-goals

- Robust or scaled LRTs (`MLR`, `MLM`), ordinal or multi-group models, IPW + MBCO.
- A native or OpenMx MBCO. RMediation's complete-data `mbco()` is OpenMx-only (G6) and
  stays the complete-data route; D4-MBCO under MI lives here (decision 2026-10-07).
- Any change to the glm path's numbers. It must stay bit-identical.

## 5. Acceptance criteria

Each criterion must be able to fail; the probe's PASS lines are the seed tests.

- [ ] **Cross-engine parity.** On an observed path model (no latent variable), `infer(type = "mbco")` with `engine = "lavaan"` gives D4, p, `r4`, `nu`, `k` equal to the glm engine's to 1e-6, on real `mice` imputations (m = 5), under both `ariv` settings.
- [ ] **Single-dataset oracle.** With K identical imputations, d_S equals `lavTestLRT()` of the branch that wins; `r4 = 0`.
- [ ] **Latent mediator.** Runs end to end; each null fit equals the `0*` syntax oracle to 1e-9, `k = 1` on both branches. With a direct `Y ~ m1` row added, `b = 0` still fixes only `Y ~ Ml` (`k = 1`), the direct row stays free, and the fit equals the oracle that fixes only `Y ~ Ml` (planted defect: a null that also fixes `Y ~ m1` must fail this check).
- [ ] **Planted defects are caught:** swapping the a and b rows (caught **only** by `stacked_branch` and `p_branch_a`: the union statistic and k = 1 are symmetric in a and b, so D4 and p cannot see it; asserted in `test-mbco-provider.R`, and the lavaan tests must assert the diagnostics too); fixing the wrong row of a duplicated regression; building the table from a bare `lavaanify()` (the trap, in section 2).
- [ ] **Complete-data oracle (optional, `skip_if_not_installed("OpenMx")`).** On an observed model with K identical copies, p is within 1e-4 of `RMediation::mbco()`.
- [ ] **Refusals** before fitting, each naming the option: IPW, `MLM`, `WLSMV`, `ordered`, `group`, `sampling_weights`; a model without exactly one `mediator ~ treatment` row and one `outcome ~ mediator` row.
- [ ] **Convergence:** a non-converging null fit refuses naming the dataset and the fit; an improper solution warns once naming the datasets.
- [ ] **`mbco_d4(model = )`** equals `infer(type = "mbco")` on the same imputed data to 1e-12; supplying `model` together with a formula errors.
- [ ] **ML calibration gate (medsim; blocks the 0.8.0 release).** Normal data, MAR missingness, m = 20, 1000 replications per cell. Cells: DGP {observed path model; latent mediator, 3 indicators, loadings .8/.7/.6} x n {200, 500} x missingness {25%, 40% of the mediator or its indicators, logistic in observed variables} x null {(a, b) = (0, .3), (.3, 0), (0, 0), (0, .1), (.1, 0)}. Pass: single-null cells (0, .3) and (.3, 0) have size in 3.5-6.5% at the 5% level (about 2 Monte Carlo se at 1000 reps); intersection and near-intersection cells have size at most 6.5% (conservative is allowed and reported). Report size per cell, never pooled. Fail: the release waits and the spec is reopened.
- [ ] **MLR simulation gate (medsim; run before enabling MLR).** The same cells with non-normal data (skewed: chi-square(4) errors rescaled to unit variance; heavy-tailed: t(5) errors). The statistic is fixed in advance, so the gate evaluates one formula: per-imputation and stacked-data scaled difference tests (Satorra-Bentler 2001 via `lavTestLRT`), D4 applied to the naive LRTs, then divided by the arithmetic mean of the per-imputation scaling corrections of the winning branch (the `lavaan.mi` `pool.robust = FALSE` construction); D2 (`pool.robust = TRUE`) is run as a secondary comparison only. Pass criterion per cell as for ML, and every cell must pass: a failure in any cell keeps MLR refused in 0.8.0 and gives it its own spec.
- [ ] **`sensitivity_mnar(type = "mbco")`** runs for lavaan and matches the glm engine rung by rung on an observed model; the Q4 refusal text is gone.
- [ ] **No regression:** every existing glm MBCO test passes unchanged.
- [ ] `R CMD check --as-cran` 0/0/0 (one expected pre-CRAN note), suite green with strictly more tests, `check_pkgdown()` clean.

## 6. Implementation outline (vertical slices)

| Task | Scope | Size | Depends |
|---|---|---|---|
| T1 | Extract the log-likelihood provider from `.mm_d4_mbco()`; glm provider unchanged | S | none |
| T2 | Lavaan provider for an observed model: parTable constraint (S1, S2), parity tests | M | T1 |
| T3 | Latent mediator (S3) + the table trap test | S | T2 |
| T4 | Refusals (S4), convergence and improper-solution handling (S5, S6) | M | T2 |
| T5 | Wire `infer()` and `sensitivity_mnar()`; remove the Q4 refusal; update its tests | S | T2, T4 |
| T6 | `mbco_d4(model = )` (S7), with its parity test | S | T5 |
| T7 | MLR path: scaled difference per imputation and on the stacked data, experimental warning. **Deferred**: not implemented; `estimator = "MLR"` is refused naming the option | M | T4 |
| T8a | ML calibration simulation in `medsim` (observed and latent, incl. intersection cells); blocks 0.8.0 | M | T5 |
| T8b | MLR size simulation (the gate); decide enable or refuse. **Deferred** with T7; runs on hopper (`dev/sim-sem-mbco-calibration*.R` is the ML harness to extend) | M | T7, T8a |
| T9 | NEWS, `lavaan-sem` article section, `?infer` and `?mbco_d4` help (state: conservative at a = b = 0; direct indicator effects are not constrained) | S | T6, T8a |

Checkpoint after T3: parity and latent oracle green. Checkpoint after T5: full suite and `R CMD check`. Checkpoint after T8a: ML calibration decides whether 0.8.0 ships. Checkpoint after T8b: the MLR simulation decides whether MLR ships; ML ships as 0.8.0 without waiting on it (Q5).

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Cost: the stacked fit has K × n rows (K = 20, n = 1000 means 20,000 rows, a latent model, three fits) | Medium | Report timing in the tutorial; no new default of K |
| `parTable()` internals change in a future lavaan | Medium | Floor stays `lavaan >= 0.7-3`; the table trap test and the `0*` oracle fail loudly |
| Null fit lands on a boundary (Heywood) and the branch flips | Medium | S6 warning; `branch_mix` diagnostic already reports branch disagreement |
| D4 is justified by Chan and Meng (2022) for ML likelihood-ratio tests, not for scaled MLR statistics: the scaling factors are estimated from the data, and stacking mixes between-imputation variability into them | Medium (author chose to include MLR) | MLR is experimental, warns, and is enabled only if the T8 simulation passes |
| Direct `Y ~ indicator` effects are not part of a·b = 0, so the test says nothing about them | Low | Documented; S3 constrains only `Y ~ Ml`, `k = 1` always |
| Branch-union F reference is not exact at a = b = 0 (nonregular null) | Medium | Conservative by construction; measured in the ML calibration gate; documented |
| medfit's planned native SEM engine could replace lavaan fitting later | Low | MBCO here stays lavaan-based; a native engine would need its own provider (S8 makes that a plug-in) |

## 8. Boundaries

- **Always:** keep the glm path bit-identical; add a parity test before any lavaan code path ships.
- **Ask first:** adding a dependency (for example `lavaan.mi`, which is not needed); changing `MbcoMIResult` fields.
- **Never:** compute a p-value from an unconverged null fit; silently drop a constraint.

## 9. Resolved in the grill (2026-10-08)

1. S3: the structural path **plus the indicator links** (author's ruling; not the recommended option). **Reversed in section 10 after the adverse review.**
2. S4: **ML and MLR**, MLR experimental and gated by a simulation (author's ruling; gate recommended and accepted).
3. S6: warn once on an improper null fit and proceed.
4. S7: `mbco_d4()` **gains `model =`** (author's ruling; not the recommended option).
5. Release shape: its own **0.8.0**; ML can ship first if the MLR simulation is not ready.

## 10. Adverse review (2026-10-08)

Codex adversarial review plus a prototype (`lavaan` provider plugged into the shipped D4 pooling; 300 reps per null, n = 200, m = 5, MAR).

| # | Finding | Outcome |
|---|---|---|
| 1 | D4 F reference unsupported at the a = b = 0 intersection | Partly refuted: the glm engine already ships this reference; prototype size 0.050 (a = 0, b = .3), 0.007 (a = b = 0), 0.007 (a = 0, b = .1): conservative, not liberal. Added the ML calibration gate and the documented conservatism. |
| 2 | Latent b-null fixes direct indicator rows, testing more than a·b = 0 | Accepted. S3 reversed to the structural row only. |
| 3 | MLR gate underspecified | Accepted. Scenarios, statistic and per-cell criterion fixed in section 5. |
| 4 | Probe exits 0 on failure | Accepted. Fixed in the probe. |

Limits of the prototype: observed-variable models only; it shows lavaan equals glm to 7e-11 and says nothing about latent or MLR calibration, which the gates measure.
