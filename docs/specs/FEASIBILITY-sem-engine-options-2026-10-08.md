# FEASIBILITY: SEM engine options for missingmed 0.6.0

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | Study only; no package code changed, spikes ran in a scratch directory. **Updated 2026-10-08 (13:10):** `origin/dev` already ships the lavaan engine and the S4 removal as 0.6.0 (PRs #40-#43), so this study now confirms the shipped choice instead of gating it. |
| **Context** | [SPEC](SPEC-s7-sem-engine-2026-09-23.md) (Q1-Q4, G1-G7) and [PLAN](PLAN-s7-sem-engine-2026-10-08.md) (T0 done) choose `lavaan::sem()` as the engine and delegate extraction to `medfit::extract_mediation()`. |
| **Question** | Does any alternative beat that baseline: (1) port lavaan/OpenMx engines, (2) write a new optimizer, (3) use Python `semopy`? |

Evidence labels: **[V]** verified this session by a command; **[A]** assumed or recalled, not checked; **[?]** unknown.

## Recommendation

**Keep lavaan as the engine (baseline B). All three alternatives are no-go for 0.6.0.**

- Shipped: PLAN T1-T9 landed in 0.6.0 (PRs #40-#42, version bump #43). No change needed.
- Park two follow-ups: a *validated* custom ML optimizer as a possible fallback (see option 2, "conditional later"), and a semopy cross-check as an optional test oracle (see option 3).

## Comparison matrix

| Criterion | **B. lavaan baseline** | 1. Port lavaan/OpenMx | 2. Own optimizer | 3. semopy |
|---|---|---|---|---|
| Parity with lavaan estimates and vcov | Exact (it is lavaan) | Achievable, with a large test burden | Point estimates yes; vcov and SE types are extra work | Observed and latent models matched lavaan **[V]** |
| medfit/RMediation delegation | Works today: `extract_mediation(<lavaan>)` incl. latent mediator and `outcome=` **[V]** (PLAN T0) | Needs a new extractor or a fake lavaan object **[A]** | Needs a new extractor **[A]** | Needs a new extractor and a cross-language bridge **[A]** |
| Rubin pooling and D4-MBCO | Pooling works; MBCO refused in 0.6.0 (Q4) | Same as B, once the extractor exists | Same | Same |
| IPW (G1 `sampling.weights`, sandwich SE) | Supported **[V]** (T0: 8e-16 vs glm) | Must reimplement | Must reimplement | No weights argument in `fit()` **[V]**; `se_robust` exists for the unweighted case **[V]** |
| CRAN viability | Pure R dependency, already imported | Compiled or GPL-vendored code; heavy review | Pure R is feasible; no new dependency | **Poor**: Python runtime on CRAN, CI and every user |
| License fit (missingmed is GPL-2) | GPL (>= 2): compatible **[V]** | lavaan code: compatible. **OpenMx is Apache-2.0 [V]; incompatible with GPL-2-only per the FSF [A].** | Own code: no issue | MIT **[V]**: compatible, but the runtime problem remains |
| Effort | Lowest (T1-T7) | Highest; see option 1 | Medium to high | Medium to high |
| Maintenance risk | Upstream-maintained | Fork drift from upstream | Own code forever | Last PyPI release 2024-01-04 (about 21 months old) **[V]** |
| Hard cases (small n, Heywood) | Inherits lavaan; `post.check` flags them **[V]** | Inherits only if the port is complete | The unconstrained optimizer converged; boundary handling decides (spike) | One latent fit worked; no stress test **[?]** |
| Verdict | **Go** | **No-go** | **No-go now; conditional later** | **No-go as engine; optional test oracle** |

## Option 1: port engines from lavaan / OpenMx

**What a port covers.** A usable SEM engine needs model syntax parsing, a parameter table, implied moments, the ML discrepancy and its gradient, a minimizer, information-matrix SEs, robust (sandwich) SEs, and fit diagnostics. That is the part of lavaan that missingmed's S7 path would call. lavaan 0.7.2 is installed locally **[V]**, but I did not measure its source size. It is a large codebase **[A]**; OpenMx is mostly compiled C++ with its own optimizer back ends (NPSOL, SLSQP, CSOLNP) **[A]**.

**Findings.**
- **Licenses.** lavaan is GPL (>= 2) **[V]**, so vendored lavaan code can ship under missingmed's GPL-2. OpenMx is Apache-2.0 **[V]**. The FSF treats Apache-2.0 as incompatible with GPL-2-only **[A]**; missingmed is `GPL-2` **[V]**. Porting OpenMx code would therefore need a relicense to GPL-3 (the author can relicense, which would remove this obstacle, subject to every copyright holder agreeing) or a legal read. **The license is not decisive:** the port is rejected on cost, duplication and maintenance below, whatever the license.
- **Duplication.** The plan already gets lavaan through `lavaan::sem()` and the medfit extractor **[V]**. A port re-creates that with a permanent obligation to track upstream bug fixes (improper-solution handling, new estimators).
- **OpenMx.** The spec (G6) already ends OpenMx support with the S4 removal; a port would reverse that decision.
- **Scope the plan cares about.** 0.6.0 needs observed and latent-mediator models, MI pooling and IPW (spec section 5). Only a small subset of lavaan is used, which argues for calling lavaan, not copying it.

**Size of lavaan [V].** lavaan 0.7.2 source (CRAN tarball): 132,422 lines of R in 231 files, no compiled code. Files a mediation engine would touch (line counts of the whole file family):

| Family | Lines | | Family | Lines |
|---|---|---|---|---|
| `lav_model` | 13,053 | | `lav_model_gradient` | 2,932 |
| `lav_partable` | 9,289 | | `lav_start` | 1,241 |
| `lav_samplestats` | 5,452 | | `lav_model_vcov` | 1,076 |
| `lav_syntax` | 3,131 | | `lav_optim` | 949 |
| `lav_model_information` | 813 | | `lav_model_objective` | 500 |

These total about 38,000 lines but include categorical, multilevel and multigroup code. **[A, estimate]** A continuous-ML subset with robust SEs and `sampling.weights` is 5,000-8,000 lines, and the port costs 6-10 weeks of focused work including the medfit extractor, parity tests and improper-solution handling, followed by permanent upstream tracking.

**Verdict: No-go.** Highest effort and risk, and no capability gain over calling lavaan. Confirmed by what shipped: the lavaan engine in 0.6.0 reused `lavaan::sem()` and `extract_mediation()` without a port.

## Option 2: write a powerful, robust optimizer

**Spike (read-only, scratch script).** A hand-written ML discrepancy for a latent-mediator model (`M =~ m1+m2+m3; M ~ X; Y ~ M + X`; 11 free parameters), minimized from naive starting values (loadings 1, variances 1, paths 0), against `lavaan::sem()`. 200 simulated datasets per sample size.

| n | lavaan converged | lavaan proper solution | unconstrained BFGS (numeric gradient) converged / `b` matches lavaan | `nlminb` with variance bounds converged / `b` matches lavaan |
|---|---|---|---|---|
| 50 | 99.5% | 79.0% | 100% / 99.5% | 100% / 79.4% |
| 200 | 100% | 99.0% | 100% / 100% | 100% / 99.0% |

**What the spike shows [V], on this one model and simulation design:**
- Reaching the minimum is not the hard part. A plain unconstrained optimizer from naive starts matched lavaan's `b` in 99.5-100% of replications.
- The hard part is **improper solutions**: 21% of fits at n = 50 had a negative variance or similar. An unconstrained optimizer reproduces lavaan's answer there (including the Heywood case); a bounded optimizer returned a different boundary solution (the 79% match equals lavaan's proper-solution rate). So "robust" is a *policy* choice (allow, bound, or reparameterize), not an optimization-power question.

**What the spike does not show [?]:** other model shapes (multiple outcomes, correlated errors, equality constraints), MLR/robust SEs, ill-conditioned or near-collinear data, missing-data estimation, and analytic gradients. The toy hard-codes one model's implied covariance; a general engine needs the parameter-table and syntax machinery from option 1.

**Findings.**
- A *specialized* optimizer for the mediation model family (observed and latent mediator, ML) is plausible in pure R, with no new dependency.
- It still needs: a model-syntax layer, standard errors (expected or observed information, sandwich), `post.check`-style diagnostics, extraction into `medfit::MediationData`, and a parity test suite against lavaan. Those, not the optimizer, are most of the work.
- Benefit over B is unproven: lavaan already converged 99.5-100% here.

**Verdict: No-go for 0.6.0; conditional later.** Revisit only if a measured lavaan failure rate on missingmed's own use cases (MI at m >= 20 with latent mediators, per PLAN risk 2) justifies it. A fallback for the narrow case "lavaan did not converge on imputation k" is the smallest version worth considering.

### nloptr as the optimizer [V]

Same discrepancy and simulation as above (100 fits per cell, `b` within 1e-3 of lavaan's; seconds are total for 100 fits; numeric gradients).

| Optimizer | Match, n = 50 | Match, n = 200 | Seconds, n = 50 |
|---|---|---|---|
| `stats::nlminb` (lavaan's default) | 100% | 100% | 0.64 |
| nloptr `LD_LBFGS` | 100% | 99% | 1.5 |
| nloptr `LD_SLSQP` | 100% | 100% | 1.9 |
| nloptr `LD_MMA` | 98% | 100% | 14.4 |
| nloptr `LN_BOBYQA` (variance bounds) | 82% | 98% | 1.0 |
| nloptr `LN_NEWUOA_BOUND` | not rerun | not rerun | 76 s on one fit; dropped |

- nloptr 2.2.1 is LGPL (>= 3), compiled, and needs cmake to build on Linux and macOS when no system nlopt (>= 2.7.0) exists **[V]**. `nlminb` is in base R.
- nloptr matches `nlminb` at best, so it offers no accuracy gain. The bounded algorithm lost accuracy because it forces boundary solutions in improper cases (as in the first spike).
- Where nloptr could matter is **constrained** problems (SLSQP handles nonlinear equality and inequality constraints natively); see the next section.

### Nonlinear constraints in lavaan [V, limited]

The author reports that lavaan does not handle nonlinear constraints. Test on `M~a*X; Y~b*M+cp*X` (n = 300), observed variables:

| Constraint | Converged | Result |
|---|---|---|
| `a*b == 0` (nonlinear equality) | yes | `fmin` 0.047577, equal to the `a == 0` fit (the better of the two linear fits, as it should be) |
| `a == 0` / `b == 0` | yes | `fmin` 0.047577 / 0.053074 |
| `a*b == 0.05` | yes | `fmin` 0.009563, `a` 0.217, `b` 0.230 |
| `a^2 + b^2 < 0.01` (inequality) | yes | converged, but `df` reported as 0: inequality constraints are not counted in the degrees of freedom |

On simple cases lavaan handled nonlinear equality and inequality constraints. **This does not refute the author's report**: it was one small observed model. Not tested **[?]**: many constraints, near-degenerate geometry, latent models, small samples, constraint Jacobians that vanish at the solution, and pooling across imputations. The author's failing case, if any, should become a test; the repo (`dev/`, `docs/`, code) holds no record of one **[V, grep]**. The shipped MBCO design uses linear constraints (`a == 0`, `b == 0`), so it does not depend on nonlinear support.

## Option 3: examine Python semopy (https://semopy.com/)

**Facts.**
- Version 2.3.11, uploaded 2024-01-04; MIT license **[V]** (PyPI classifier). Dependencies: scipy, numpy, pandas, sympy, scikit-learn, statsmodels, numdifftools **[V]**.
- Estimators in `Model.fit()`: `MLW`, `ULS`, `GLS`, `WLS`, `DWLS`, `FIML`; default solver SLSQP; accepts lavaan-style syntax; `se_robust` option in `inspect()` **[V]**.
- No sampling-weights argument in `fit()` **[V]** (checked the signature and grepped the source), so it cannot back G1 (IPW) without custom work.

**Spike [V].** Installed in an isolated virtualenv; fitted `M ~ X + C; Y ~ M + X + C` (n = 400) and the latent model from option 2 (n = 100), compared with lavaan 0.7.2:

| Case | Max difference visible in the printed table |
|---|---|
| Observed path model: paths, residual variances, SEs | Agree to the printed 6 digits (e.g. `M~X` 0.454055 / 0.053586) |
| Latent mediator: loadings, paths, variances, SEs | Agree to 3 digits (e.g. `Y~M` 0.534002 vs lavaan 0.534; SE 0.131) |

**Findings.**
- Numerically it agrees with lavaan on these cases, so it is credible as an independent **test oracle** (a known-answer cross-check, not a runtime dependency).
- As an **engine** it fails the constraints: a Python runtime in an R package breaks CRAN norms and CI simplicity (reticulate or subprocess adds install and portability cost) **[A]**; no weights for IPW; stale release cadence; no medfit extractor; the MI loop would cross the language boundary m times.
- Its estimators (FIML) overlap with what missingmed delegates to `mice`; FIML would be a different missing-data strategy, outside this package's MI/IPW scope.

**Verdict: No-go as an engine. Optional: use it once, offline, to cross-validate lavaan parity tests (outside the package and CI).**

## Open questions

1. Which concrete model and constraint failed in lavaan? (See the nonlinear-constraints section; a reproducible case decides whether a constrained optimizer such as nloptr `SLSQP` is worth adding.)
2. Does the author want a **fallback** for lavaan non-convergence in MI (option 2's narrow form), or is G2's "refuse and name the imputations" sufficient? It is cheap to decide after real runs.
3. If OpenMx is ever revived (G6 defers it), a relicense to GPL-3 would be needed only to copy its code; calling it as a dependency needs none.
4. Spike limits: one simulated latent model, my own discrepancy implementation, 200 replications per cell. A wider stress test (ill-conditioned data, MLR, correlated errors) is needed before any claim beyond "naive optimizers are not the bottleneck."
5. The maintenance rate of lavaan/OpenMx and the 6-10 week port estimate were not measured [A].

## Reproduction

- Option 2: scratch script `opt.R` (session scratchpad); not committed. Re-create from the description above if needed.
- Option 3: `uv venv` + `uv pip install semopy` in a scratch directory; models and data as described. Python 3.14 environment.
