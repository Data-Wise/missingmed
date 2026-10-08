# PLAN (exploratory): a native SEM engine on nloptr, independent of lavaan and OpenMx

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | EXPLORATORY. Not grilled, not approved, no package code written. Needs the author's decisions in section 7. |
| **Builds on** | [FEASIBILITY-sem-engine-options-2026-10-08.md](FEASIBILITY-sem-engine-options-2026-10-08.md). Option 2 there was "no-go now"; the author asked for a plan anyway, to be independent of lavaan and OpenMx. |
| **Evidence labels** | **[V]** verified by a command this session; **[A]** assumed or recalled; **[?]** unknown. |

## 1. What "independent" can and cannot mean

- missingmed's own fitting code can stop calling lavaan and OpenMx. OpenMx is already gone from `Imports` in 0.6.0 **[V]** (`origin/dev`).
- **lavaan still installs with missingmed**, because `RMediation` (a hard Import of missingmed) imports lavaan (`Imports: ... lavaan (>= 0.5-20) ...`) **[V]**, and suggests OpenMx **[V]**. `medfit` only suggests lavaan **[V]**. So install-level independence needs `RMediation` to drop lavaan, which is a different repo and not this plan's to change (author's call).
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
| Optimizer | `nloptr`: `NLOPT_LD_SLSQP` default (handles bounds and equality/inequality constraints with the same call); `LD_LBFGS` as fallback; analytic gradient | Spike: SLSQP matched lavaan 100% at n = 50 and 200 in the earlier comparison; `nlminb` has no constraint support |
| Start values | Simple moment-based: fixed loadings 1, variances at half the observed variance, paths 0 | Used in the spike; a multi-start retry on failure is part of v1 |
| Improper solutions | Unbounded by default and flagged (negative variance, non-PD), same as the shipped G2 "warn once, name the imputations" policy | The earlier spike showed bounds change the answer in Heywood cases, so the policy must be explicit |
| SEs | Expected information (n/2) J' (Sigma^-1 x Sigma^-1) J; sandwich with casewise scores for weights (IPW) | The first is verified against lavaan; the sandwich is v1 work |
| Output | Build a `medfit::MediationData` directly (constructor takes `a_path`, `b_path`, `c_prime`, `estimates`, `vcov`, `n_obs`, `source_package`, and more **[V]**) | Keeps `pool()`, `infer("mc")` and RMediation unchanged |
| Integration | New `engine = "native"` beside `"glm"` and `"lavaan"`, same `set_md_mediation()` API (`model`, `outcome`, `fit_args`) | lavaan stays during the transition so the engines can be compared |

## 4. Scope tiers

| Tier | Content | Gate |
|---|---|---|
| v0 | Parser subset: `=~`, `~`, `~~`, labels, fixed values; ML; observed and latent mediator; SEs; extractor to `MediationData`; convergence and improper-solution diagnostics | Parity with lavaan at 1e-6 (estimates) and 1e-5 (SEs) on at least 5 models, including every spec section 5 case that applies |
| v1 | `sampling.weights` / IPW with sandwich SEs; multi-start retry; `fit_args` for the native engine | IPW point estimates equal the glm IPW path to 1e-6 (the shipped lavaan IPW criterion) |
| v2 | MBCO for SEM: constrained refits for `a == 0` and `b == 0`, take the better, with the author's ruling on the latent-mediator `b` | Known-answer test against lavaan constrained fits (the case I ran above) |
| Out of scope | Categorical and ordinal indicators, multilevel, multigroup, FIML, mean structure unless needed, robust estimators other than the sandwich | Not needed for mediation under MI/IPW **[A]** |

## 5. Tasks (sizes: XS 1 file, S 1-2, M 3-5)

| # | Task | Size | Acceptance |
|---|---|---|---|
| N0 | Decisions in section 7; commit the spike as `dev/spike-ram-nloptr.R` | S | Author sign-off |
| N1 | RAM core: matrices, implied covariance, discrepancy, analytic gradient, expected information | M | Gradient test at 1e-8; known-answer fit equals the stored lavaan values |
| N2 | Parser for the subset; parameter table; start values; validation (treatment, mediator, outcome present, `mediator ~ treatment`, `outcome ~ mediator`) | M | Same errors as the lavaan branch's validation; unsupported syntax errors by name |
| N3 | Fit driver on `nloptr`; convergence and improper-solution diagnostics | S | Planted non-convergence and Heywood cases behave as G2 |
| N4 | Extractor to `medfit::MediationData`; `engine = "native"` in `run()`; pooling, `infer("mc")` | M | Pooled `a`, `b`, `c_prime` equal the lavaan engine's to 1e-6 |
| N5 | Parity suite vs lavaan (Suggests only), observed + latent, several n | S | Skips cleanly when lavaan is absent |
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
| License: `nloptr` is LGPL (>= 3) **[V]**; missingmed is `GPL-2` **[V]**. LGPL-3 with GPL-2-only is generally treated as incompatible **[A]** | Med | Relicense to `GPL (>= 2)` or GPL-3; the author said relicensing is possible; confirm all copyright holders |
| Build burden: `nloptr` is compiled and needs cmake when no system nlopt exists **[V]** | Low-Med | CRAN builds binaries; document the Linux requirement |
| Maintenance: own code for model syntax and SEs forever | Med | Keep the subset small; lavaan stays as the oracle in tests |
| Install-level independence is not achieved while `RMediation` imports lavaan **[V]** | Med | Decide whether to ask RMediation to drop it (section 7) |
| The author's reported lavaan nonlinear-constraint failure is still unreproduced **[?]** | Low | Send the failing case; it becomes a test for the native engine too |

## 7. Decisions needed from the author

1. **Scope of independence:** fitting code only (this plan), or also ask `RMediation` to drop its lavaan import? Recommended: fitting code only first; RMediation is another repo.
2. **Engine relationship:** add `"native"` beside lavaan (Recommended: lets parity be measured before any removal), or replace lavaan outright?
3. **Relicense:** to `GPL (>= 2)` or GPL-3 so `nloptr` is clean? Recommended: `GPL (>= 2)`, which keeps GPL-2 users and is compatible with `nloptr`'s LGPL-3 **[A]**.
4. **Go/no-go point:** a gate after N5 (v0 parity) before spending on v1 and v2? Recommended: yes.
5. **The failing lavaan case:** which model and constraint? It would show whether constraints are the driver and which tests to add first.

## 8. Recommendation

**Conditional go, staged.** Build N0-N5 (v0) as an additional `engine = "native"` with lavaan as the parity oracle, then stop at the gate. The spike shows the math and the optimizer work; what remains is engineering and parity testing across more model shapes. Do not remove the lavaan engine until parity holds on those models.

First action: commit the spike script to `dev/` so the numbers in section 2 are reproducible.
