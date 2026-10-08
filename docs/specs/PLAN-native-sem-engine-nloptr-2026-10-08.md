# PLAN (exploratory): a native SEM engine on nloptr, independent of lavaan and OpenMx

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | GRILLED 2026-10-08 (J1-J6, [GRILL-native-sem-engine-nloptr-2026-10-08.md](GRILL-native-sem-engine-nloptr-2026-10-08.md)); amended to match. Not yet approved for building; open questions 1, 4 and 6 of the ledger gate the start. No package code written. |
| **Builds on** | [FEASIBILITY-sem-engine-options-2026-10-08.md](FEASIBILITY-sem-engine-options-2026-10-08.md). Option 2 there was "no-go now"; the author asked for a plan anyway, to be independent of lavaan and OpenMx. |
| **Evidence labels** | **[V]** verified by a command this session; **[A]** assumed or recalled; **[?]** unknown. |

## 0. Decisions that shape this plan (from the grill)

| # | Decision |
|---|---|
| J1 | The engine is built in **medfit** (the shared foundation), not missingmed. missingmed becomes a consumer. |
| J2 | The v0 gate is lavaan parity **plus** reproducing RMediation's OpenMx `mxCompare` diffLL on its MBCO test cases. |
| J3 | nloptr is an **Imports** of medfit. |
| J4 | This repo holds the spec and handoff; a medfit session builds. No cross-repo writes from this session. |
| J5 | missingmed relicenses to **GPL (>= 3)**. |
| J6 | nloptr is the primary optimizer (SLSQP default, L-BFGS unconstrained). nlminb is not a fallback. |

Where the sections below conflict with this table, the table wins.

## 1. What "independent" can and cannot mean

- The fitting code in the verse can stop calling lavaan and OpenMx. missingmed already dropped OpenMx from `Imports` in 0.6.0 **[V]** (`origin/dev`). **RMediation still uses OpenMx for MBCO** (`mbco_asymp.R`, `mbco_semi.R`, `mbco_parametric.R`: `mxRun`, `mxCompare`, NPSOL) **[V]**; that is the largest remaining OpenMx use in the verse and the reason J2 gates on it.
- **lavaan still installs with missingmed**, because `RMediation` (a hard Import of missingmed) imports lavaan (`Imports: ... lavaan (>= 0.5-20) ...`) **[V]**, and suggests OpenMx **[V]**. `medfit` only suggests lavaan **[V]**. So install-level independence needs `RMediation` to drop lavaan and move MBCO off OpenMx. That is a separate repo and an open question (ledger item 3), not part of this plan's first stage.
- lavaan remains useful **in tests only** (Suggests) as the parity oracle.

## 2. Evidence: a native engine is feasible

Spike (scratch script `ram.R`, about 120 lines of R, not committed; asked to be committed in section 8): a general RAM model, Sigma = F (I-A)^-1 S (I-A)^-T F', ML discrepancy with an analytic gradient, minimized by `nloptr` SLSQP, expected-information SEs.

| Check | Result |
|---|---|
| Analytic gradient vs numeric | max difference 1.9e-10 **[V]** |
| Observed path model (n = 400): estimates and SEs vs `lavaan::sem()` | equal to 7 printed digits **[V]** |
| Latent mediator `M =~ m1+m2+m3; M~X; Y~M+X` (n = 300) | max estimate difference 3.0e-7, max SE difference 2.1e-8 **[V]** |
| Speed | 33 iterations for the path model; earlier nloptr runs: 100 fits in 1-2 s **[V]** |
| Nonlinear equality `a*b == 0` via SLSQP with an analytic Jacobian | reached lavaan's two solutions (`fmin`/2 = 0.047577 at `a`=0, 0.053074 at `b`=0) from 3 of 4 starts; **start-dependent**: two starts hit the better solution, one hit the worse; the start (0, 0) failed with status -4 because the constraint gradient vanishes there **[V]** |

The last row is the useful warning. `a*b == 0` is the union of two lines, so a local solver returns whichever it reaches. The MBCO test needs the better of the two, so the engine should solve `a == 0` and `b == 0` separately and take the smaller discrepancy (this is the shipped spec's linear-constraint design) instead of relying on one nonlinear solve.

## 3. Design

| Part | Decision proposed | Why |
|---|---|---|
| Model form | RAM matrices (A, S, F) | General: observed and latent variables, any path structure; analytic gradient is about 15 lines (verified above) |
| Syntax | A restricted lavaan-like parser: `=~`, `~`, `~~`, labels, fixed values, `==` equality constraints | lavaan's parser lives in lavaan, so independence means writing our own; a small subset is enough for mediation. Scope list in section 4. |
| Objective | Normal-theory ML on the covariance matrix | Matches what the plan's lavaan path computes (complete data per imputation) |
| Optimizer | `nloptr` first and foremost (J6): `NLOPT_LD_SLSQP` default (bounds and equality/inequality constraints in one call), `NLOPT_LD_LBFGS` for unconstrained fits; analytic gradient. **Excluded:** `LD_MMA` (about 10x slower), `LN_BOBYQA` (82% match at n = 50), `LN_NEWUOA_BOUND` (76 s on one fit). No nlminb fallback unless the author asks. | Spike: SLSQP matched lavaan 100% at n = 50 and 200 in the earlier comparison; nlminb was faster (0.64 s vs 1.9 s per 100 fits) but has no constraint support |
| Start values | Simple moment-based: fixed loadings 1, variances at half the observed variance, paths 0 | Used in the spike; a multi-start retry on failure is part of v1 |
| Improper solutions | Unbounded by default and flagged (negative variance, non-PD), same as the shipped G2 "warn once, name the imputations" policy | The earlier spike showed bounds change the answer in Heywood cases, so the policy must be explicit |
| SEs | Expected information (n/2) J' (Sigma^-1 x Sigma^-1) J; sandwich with casewise scores for weights (IPW) | The first is verified against lavaan; the sandwich is v1 work |
| Output | Build a `medfit::MediationData` directly (constructor takes `a_path`, `b_path`, `c_prime`, `estimates`, `vcov`, `n_obs`, `source_package`, and more **[V]**) | Keeps `pool()`, `infer("mc")` and RMediation unchanged |
| Integration | **In medfit:** `engine = "native"` in `fit_mediation()` (medfit already has `engine` and `engine_args`). **In missingmed:** `engine = "native"` passes through to it with the same `set_md_mediation()` API (`model`, `outcome`, `fit_args`). missingmed's shipped `engine = "lavaan"` stays (assumption; ledger open question 1) | lavaan stays so the engines can be compared |

## 4. Scope tiers

| Tier | Content | Gate |
|---|---|---|
| v0 | Parser subset: `=~`, `~`, `~~`, labels, fixed values; ML; observed and latent mediator; SEs; extractor to `MediationData`; convergence and improper-solution diagnostics | **J2:** parity with lavaan at 1e-6 (estimates) and 1e-5 (SEs) on at least 5 models, including every spec section 5 case that applies, **and** reproduction of RMediation's OpenMx `mxCompare` diffLL on its existing MBCO test cases (OpenMx as the test-only oracle) |
| v1 | `sampling.weights` / IPW with sandwich SEs; multi-start retry; `fit_args` for the native engine | IPW point estimates equal the glm IPW path to 1e-6 (the shipped lavaan IPW criterion) |
| v2 | MBCO for SEM: constrained refits for `a == 0` and `b == 0`, take the better, with the author's ruling on the latent-mediator `b` | Known-answer test against lavaan constrained fits (the case I ran above) |
| Out of scope | Categorical and ordinal indicators, multilevel, multigroup, FIML, mean structure unless needed, robust estimators other than the sandwich | Not needed for mediation under MI/IPW **[A]** |

## 5. Tasks (sizes: XS 1 file, S 1-2, M 3-5)

**Where each task lands (J1, J4):** N0-N5 and N6-N7 are medfit work, built by a medfit session from this plan and the ledger. N8 splits: medfit docs there, and missingmed's own docs, NEWS and pass-through engine here. Nothing below is started.

| # | Task | Size | Acceptance |
|---|---|---|---|
| N0 | Resolve ledger open questions 1, 4, 6; spike already committed as `dev/spike-ram-nloptr.R` | S | Author sign-off |
| N1 | RAM core: matrices, implied covariance, discrepancy, analytic gradient, expected information | M | Gradient test at 1e-8; known-answer fit equals the stored lavaan values |
| N2 | Parser for the subset; parameter table; start values; validation (treatment, mediator, outcome present, `mediator ~ treatment`, `outcome ~ mediator`) | M | Same errors as the lavaan branch's validation; unsupported syntax errors by name |
| N3 | Fit driver on `nloptr`; convergence and improper-solution diagnostics | S | Planted non-convergence and Heywood cases behave as G2 |
| N4 | Extractor to `medfit::MediationData`; `engine = "native"` in `run()`; pooling, `infer("mc")` | M | Pooled `a`, `b`, `c_prime` equal the lavaan engine's to 1e-6 |
| N5 | Parity suite vs lavaan (Suggests only), observed + latent, several n; **MBCO known-answer vs RMediation's OpenMx cases (J2)** | M | Skips cleanly when lavaan or OpenMx is absent; the diffLL values match the OpenMx cases to the tolerance set in the medfit spec |
| N6 | IPW with sandwich SEs (v1) | M | IPW parity as above |
| N7 | SEM MBCO via constrained refits (v2) | M | Known-answer test; both constraint solves reported |
| N8 | Docs, NEWS, `_pkgdown.yml`, vignette; decide the default engine | S | Per `pre-pr-testing.md` and `e2e-before-pr.md` |

**Effort [A]:** my estimate is 4-6 weeks of focused work for v0 plus v1, and 2-3 more for v2. The spike's size (about 120 lines for parity on two models) suggests the RAM core is small; the parser, diagnostics, weights, tests and documentation are most of the effort.

## 6. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Parity drift on models the spike did not cover (equality constraints, correlated errors, several outcomes) | High | N5 grows with each model class; v0 gate requires at least 5 models |
| Local minima and start dependence (seen with `a*b == 0`) | Med | Solve linear constraints separately; multi-start in v1; report which start won |
| Improper solutions at small n (21% of fits at n = 50 in the earlier spike) | Med | Same warn-once policy as lavaan; do not silently bound |
| License: `nloptr` is LGPL (>= 3) **[V]**; missingmed is `GPL-2` **[V]**; it already imports GPL (>= 3) medfit and RMediation | Med | **J5:** relicense missingmed to GPL (>= 3); confirm all copyright holders first (ledger item 2: one committer appears as "Test User") |
| **Build burden on the whole verse (J3):** nloptr in medfit's `Imports` means every dependent (probmed, mediationverse, RMediation, missingmed) installs a compiled package that needs cmake when no system nlopt (>= 2.7.0) exists **[V]** | Med-High | Check on the CRAN platforms and r-hub before the medfit release; document the Linux/macOS requirement; if it fails, move nloptr to Suggests (the recommended alternative) |
| medfit is being worked on by another session (Ext D multilevel) **[V]** `.STATUS` | Med | J4: hand off a spec, do not write there from this session |
| Version skew: medfit 0.5.0 is GitHub-only, CRAN has 0.3.2 **[V]** | Med | Ledger item 4: pick the release and the floor |
| Maintenance: own code for model syntax and SEs forever | Med | Keep the subset small; lavaan stays as the oracle in tests |
| Install-level independence is not achieved while `RMediation` imports lavaan **[V]** | Med | Decide whether to ask RMediation to drop it (section 7) |
| The author's reported lavaan nonlinear-constraint failure is still unreproduced **[?]** | Low | Send the failing case; it becomes a test for the native engine too |

## 7. Decisions (resolved in the grill; open items in the ledger)

| Original question | Resolution |
|---|---|
| 1. Scope of independence | J1: build in medfit; RMediation's OpenMx/lavaan use is a separate open item (ledger 3) |
| 2. Engine relationship | Add `"native"`; keep missingmed's lavaan engine for now (ledger 1 open) |
| 3. Relicense | J5: GPL (>= 3) |
| 4. Go/no-go point | J2: the v0 gate, including the OpenMx MBCO known-answer |
| 5. The failing lavaan case | Resolved by lavaan's release notes: the 0.7-2 constraint bug under `optim_parscale` and the retry cascade ([report](../reports/REPORT-lavaan-0.7-3-changes-2026-10-08.md)); no separate failing case needed |

## 8. Recommendation

**Conditional go, staged, in medfit.** A medfit session builds N0-N5 (v0) as `engine = "native"` with lavaan and OpenMx as test-only oracles, then stops at the J2 gate. The spike shows the math and the optimizer work; what remains is engineering and parity testing across more model shapes. Do not remove the lavaan engine until parity holds on those models.

First action: the author answers ledger open questions 1, 4 and 6; then a medfit session starts from this plan, the ledger and `dev/spike-ram-nloptr.R`.
