# HANDOFF: native nloptr SEM engine for medfit

| | |
|---|---|
| **Date** | 2026-10-08 |
| **From** | missingmed session (author: Davood Tofighi). Nothing has been written in the medfit repo. |
| **For** | A medfit session. Read this file first, then the sources in section 7. |
| **Status** | Design grilled and decided (J1-J17); no engine code exists beyond three spike scripts. Not started. |
| **Target release** | medfit 0.6.0, GitHub/r-universe first (J11). medfit is at 0.5.0 on GitHub; CRAN has 0.3.2. |

## 1. Goal

A native structural equation engine in medfit, `fit_mediation(engine = "native")`, built on **nloptr**, independent of lavaan and OpenMx at fit time. Its first consumers are missingmed (MI and IPW pipelines) and, later, RMediation's MBCO (currently OpenMx-based). lavaan and OpenMx stay as **test-only oracles**.

## 2. Decisions already made (do not re-litigate; the ledgers hold the reasoning)

| # | Decision |
|---|---|
| J1 | Build in medfit. |
| J2, J7 | v0 gate: **OpenMx** parity (>= 5 models, 1e-6 on estimates) **plus** reproducing RMediation's OpenMx `mxCompare` diffLL on its MBCO test cases. lavaan is an optional second oracle, not a gate. |
| J3 | nloptr goes in medfit's **Imports** (the author chose this over Suggests). Cost: every dependent installs a compiled LGPL (>= 3) package that needs cmake when no system nlopt (>= 2.7.0) exists. Check CRAN platforms and r-hub before release; if it fails, fall back to Suggests. |
| J4 | Spec in missingmed, medfit session builds. |
| J5, J12 | missingmed is now GPL (>= 3) (done, PR #48). medfit is already GPL (>= 3). |
| J6 | nloptr first: `NLOPT_LD_SLSQP` default, `NLOPT_LD_LBFGS` for unconstrained. **Exclude** `LD_MMA`, `LN_BOBYQA`, `LN_NEWUOA_BOUND` (measured slow or inaccurate). No nlminb fallback. |
| J8 | missingmed keeps its `engine = "lavaan"` and adds the native engine as a second option. |
| J9 | SEs: an `information` option, **observed (default)** and expected. |
| J10 | Moving RMediation's MBCO off OpenMx is a **separate follow-up spec** after the v0 gate. RMediation's CRAN submission is on hold; do not touch it. |
| J13 | Own subset parser, with lavaan's `lavParseModelString()` as the test oracle. |
| J14 | Own intermediate table, with converters to lavaan's ParTable and to RAM. |
| J15 | v0 syntax: `=~`, `~`, `~~`, labels, fixed values, `:=`; `==`, `<`, `>`; `start`/`lower`/`upper` modifiers; comma shorthand and CONSTRAINT-style expressions. The last group is a **dialect** (not lavaan syntax): document it as an extension and test it separately. |
| J16 | `level:` blocks are parsed and the table has a `level` column; fitting errors clearly. Two-level estimation is a later stage. |
| J17 | Formulas (glm/lmer engines) and syntax (SEM engines) stay separate front ends. |

## 3. Task order for medfit

Sizes: XS 1 file, S 1-2, M 3-5. The first column maps to the missingmed plan's N-numbers where they exist.

| # | Task | Size | Done when |
|---|---|---|---|
| P0 | Confirm two facts first (below), then write the grammar spec for the frozen subset | S | Facts recorded in the spec; grammar subset listed with the dialect marked |
| P1 | Parser (own subset) and **our table** (with `level`) | M | Parser output equals `lavParseModelString()` on every lavaan-syntax test model; dialect features have their own tests |
| P2 | Converters: table to lavaan ParTable and to RAM, with round-trip tests | M | Round trip against `lavaanify()` on the test models; RAM matrices reproduce the implied covariance |
| N1 | RAM core: implied covariance, ML discrepancy, **analytic gradient**, observed and expected information | M | Gradient vs numeric < 1e-8; known-answer fit |
| N3 | Fit driver on nloptr: starts, convergence, improper-solution diagnostics (warn once, name the problem), multi-start retry | S | Planted non-convergence and Heywood cases behave as the missingmed lavaan engine's G2 policy |
| N4 | Extractor to `medfit::MediationData`; `engine = "native"` in `fit_mediation()` | M | `MediationData` valid (it needs raw data with `nrow == n_obs`); RMediation `ci_mediation_data()` runs on it |
| N5 | **Parity suite vs OpenMx and the MBCO known-answer** | M | The J2 gate, including constrained and bounded cases; skips cleanly if OpenMx is absent |
| N6 | IPW with sandwich SEs (`sampling_weights`) | M | IPW point estimates equal the glm IPW path to 1e-6 (as missingmed's lavaan IPW criterion) |
| N7 | SEM MBCO via constrained refits (`a == 0` and `b == 0` solved separately, take the better) | M | Known-answer test; both solves reported |
| N8 | Docs, NEWS, pkgdown index, release to GitHub (0.6.0) | S | Per medfit's own release process |

**Gate:** stop after N5 for the author's go/no-go before N6-N7. Two-level estimation (J16) and RMediation's migration (J10) are separate later specs.

### P0: two facts to confirm first

1. **Are OpenMx's SEs observed-information?** The spike found native (expected-information) SEs differ from OpenMx's by up to 2.4e-3 on a latent model. The inference that OpenMx uses observed information is not verified. J9's default depends on it.
2. **OpenMx covariance input.** `mxData(type = "cov", numObs = n)` treats the matrix as the unbiased (n - 1) covariance; pass `S * n/(n - 1)` when comparing against a divisor-n ML engine. Bake this into the oracle helper.

## 4. What the spikes already show [V]

Scripts are in missingmed `dev/`: `spike-ram-nloptr.R`, `spike-ram-nloptr-vs-openmx.R`, `spike-openmx-extract.R`.

| Check | Result |
|---|---|
| Analytic gradient vs numeric | max difference 1.9e-10 |
| Observed path model vs OpenMx | estimates and SEs equal to 6 digits |
| Latent mediator vs OpenMx | max estimate difference 2.3e-6; max SE difference 2.4e-3 (expected vs observed information) |
| Latent mediator vs lavaan (expected information) | max estimate 3.0e-7, max SE 2.1e-8 |
| nloptr SLSQP vs lavaan | 100% match at n = 50 and 200 (100 fits per cell); nlminb equally accurate and about 3x faster, but has no constraints |
| Nonlinear `a*b == 0` via SLSQP | start-dependent: 3 of 4 starts reached lavaan's solutions (better or worse one), the start (0, 0) failed because the constraint gradient vanishes there |
| OpenMx fit to `MediationData` to RMediation MC CI | works; indirect effect 0.1962 = 0.4541 x 0.4320 |

## 5. Risks to watch

- **nloptr in Imports** (J3): cmake and CRAN platform risk for the whole verse.
- **Improper solutions** are the real difficulty, not optimization: 21% of fits at n = 50 on the latent toy model. Unbounded and flagged is the policy; bounds change answers.
- **Constraints are start-dependent** (`a*b == 0`): solve linear constraints separately; report which start won.
- **Dialect** (J15): comma shorthand and CONSTRAINT-style expressions are not lavaan syntax; users must not read "lavaan syntax" as a promise.
- **Three table representations** (J14): drift between our table, ParTable and RAM; the round-trip tests are the guard.
- **Collision with the Ext D multilevel work** in medfit (`.STATUS` next step): coordinate branches.
- **lavaan 0.7-2 constraint bug** (confirmed by lavaan's own notes): when comparing against lavaan, use lavaan >= 0.7-3.

## 6. Open questions for the author

1. Who owns the frozen grammar spec, and does it live in medfit docs or a separate spec?
2. How are CONSTRAINT-style expressions evaluated and differentiated (symbolic, numeric Jacobian, or a restricted algebra)?
3. How is the dialect named in user docs?
4. After v0: which engines does missingmed's `pool()`/`infer()` need changed to accept native results (expected: none, if `MediationData` is the interface)?

## 7. Read these, in this order

All in missingmed (`docs/specs/` unless noted):

1. `PLAN-native-sem-engine-nloptr-2026-10-08.md` (section 0 table first)
2. `GRILL-native-sem-engine-nloptr-2026-10-08.md` (J1-J12)
3. `GRILL-sem-syntax-framework-2026-10-08.md` (J13-J17, with the parser evidence)
4. `FEASIBILITY-sem-engine-options-2026-10-08.md`
5. `../reports/REPORT-lavaan-0.7-3-changes-2026-10-08.md`
6. `../../dev/spike-*.R`

In medfit (read first before writing): `R/extract-lavaan.R` (the existing extractor, 1,213 lines), `R/classes.R` (`MediationData`), `planning/specs/GRILL-multilevel-mediation-ext-d-2026-09-25.md`, and `.STATUS`.

## 8. Constraints for the medfit session

- Follow medfit's own branch workflow and release process; this brief does not override them.
- Do not touch RMediation (CRAN submission on hold, J10).
- Do not start before the author opens the session and confirms the open questions in section 6 that block P0.
