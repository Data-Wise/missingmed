# GRILL: native nloptr SEM engine (decision ledger)

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Target** | [PLAN-native-sem-engine-nloptr-2026-10-08.md](PLAN-native-sem-engine-nloptr-2026-10-08.md) |
| **Sweep** | Read-only survey of the mediationverse repos (`~/projects/r-packages/active/*`, outside this repo; nothing written there) |
| **Status** | 5 branches resolved (J1-J5); open items at the end. The PLAN is **not yet amended** to match these decisions. |

## Evidence from the mediationverse sweep [V]

- **RMediation's MBCO uses OpenMx**: `mbco_asymp.R`, `mbco_semi.R`, `mbco_parametric.R` call `OpenMx::mxRun`/`mxCompare` with NPSOL (`OpenMx (>= 2.13)` in `DESCRIPTION`). `ci.R`/`pMC.R`/`qMC.R` use `lavaan::lav_matrix_vech_reverse`, `parameterEstimates`, `coef`, `vcov`; `ProductNormal_from_lavaan` exists. lavaan is an `Imports` of RMediation 1.7.0 (CRAN: 1.6.1).
- **medfit** (0.5.0 on GitHub; CRAN 0.3.2): GPL (>= 3); `Imports` S7, stats, methods, checkmate, generics, MASS; lavaan is in Suggests; `R/extract-lavaan.R` (1,213 lines); `fit_mediation()` has `engine` and `engine_args`; the OpenMx extractor was "postponed", and `IDEAS.md` lists "OpenMx engine for SEM". Its `.STATUS` next step: plan for the approved Ext D module-1 (multilevel) spec.
- **Licenses**: medfit, RMediation, medsim GPL (>= 3); probmed, medrobust MIT; **missingmed GPL-2**. missingmed already imports medfit and RMediation (GPL >= 3).
- **missingmed contributors** (`git shortlog`): 77 + 5 commits by the author, 59 + 3 by a "Test User" identity with `test@example.com` / the author's gmail (looks like test or CI commits; unverified whether anyone else holds copyright).
- **lavaan release notes** (<https://lavaan.ugent.be/history/dot7.html>): see [REPORT-lavaan-0.7-3-changes](../reports/REPORT-lavaan-0.7-3-changes-2026-10-08.md). Relevant here: 0.7-2 constraint bug under `optim_parscale` including automatic retries; 0.7-3 runaway-solution detection; snake_case rename.

## Decisions

| # | Question | Decision | Consequence recorded |
|---|---|---|---|
| J1 | Where does the engine live; what does independence cover? | **Build in medfit** (the shared foundation) | RMediation can later replace OpenMx for MBCO; cross-repo work needs the author's explicit go per write; a medfit release is needed before missingmed can use it. Rejected: prototype in missingmed; fitting-only in missingmed (does not achieve independence); constrained-refits-only (not independence for ordinary fits). |
| J2 | What must v0 prove? | **Parity (>= 5 models, 1e-6 estimates) plus reproducing RMediation's OpenMx `mxCompare` diffLL on its MBCO test cases.** *Amended by J7: the parity oracle is OpenMx, not lavaan.* | Tests the one job that justifies replacing OpenMx; needs OpenMx installed as the oracle in tests only. The hard-case benchmark was not chosen. |
| J3 | How does medfit depend on nloptr? | **Imports** (the author chose this over the recommended Suggests) | Every medfit dependent (probmed, mediationverse, RMediation, missingmed) gets a compiled LGPL (>= 3) package that needs cmake when no system nlopt exists (**[V]** DESCRIPTION). Add a CRAN-check and r-hub risk item to the plan. |
| J4 | How does the work reach medfit? | **Spec here, a medfit session builds** | No cross-repo writes from this session; the handoff brief is a deliverable of this repo; avoids collision with the Ext D work. |
| J5 | missingmed license | **GPL (>= 3)** | Aligns with the verse and with nloptr's LGPL (>= 3). Needs every copyright holder's consent (see open items) and a NEWS entry. |
| J6 | Optimizer (stated by the author, 17:24: "use nloptr first and foremost") | **nloptr is the primary optimizer** for all fits; `NLOPT_LD_SLSQP` default, `NLOPT_LD_LBFGS` for unconstrained | Spike [V]: nlminb was fastest (0.64 s vs 1.5-1.9 s per 100 fits), so the cost is milliseconds per fit. Exclude `LD_MMA` (about 10x slower), `LN_BOBYQA` (82% match at n = 50) and `LN_NEWUOA_BOUND` (76 s on one fit). nlminb is not a fallback unless the author asks. |

| J7 | Parity oracle (author, 17:26: "use openmx for parity not lavaan") | **OpenMx** is the parity oracle; lavaan is not a gate (optional second oracle) | Spike [V] (`dev/spike-ram-nloptr-vs-openmx.R`): estimates match OpenMx to 6 digits on the observed model, 2.3e-6 on the latent one. Pass OpenMx the n/(n - 1) covariance; SEs differ by 2.4e-3 on the latent model (native uses expected, OpenMx observed information **[A]**), so the engine needs an observed-information SE option for a like-for-like gate. CRAN's OpenMx has no NPSOL (`imxHasNPSOL()` FALSE) and defaults to SLSQP, the NLopt algorithm nloptr offers. OpenMx (Apache-2.0) is test-only: no license issue, heavy test dependency. |

## Open questions (not yet grilled)

1. **After medfit ships `engine = "native"`, what happens to missingmed's shipped `engine = "lavaan"`?** Keep both (Recommended: users depend on it and it shipped in 0.6.0; no longer the parity oracle per J7), or deprecate lavaan?
2. **Copyright holders for the J5 relicense**: is "Test User" the author's own CI/test identity? Any third-party code bundled in `R/`?
3. **RMediation**: does the author want the MBCO migration off OpenMx planned in the same effort (the verse-wide payoff), or left as a follow-up spec? Cross-repo; the author's call.
4. **Version targets**: medfit 0.5.0 is GitHub-only (CRAN 0.3.2). Which medfit release carries the native engine, and does missingmed's `medfit (>= ...)` floor move with it?
5. **lavaan floor in missingmed** (`>= 0.7-3`, per the report) and the snake_case guard fix: land separately, ahead of this effort.
6. **Plan amendments** needed to match J1-J6: re-home N1-N8 to medfit, add the MBCO known-answer to the gate (N5), replace "relicense to GPL (>= 2)" with GPL (>= 3), move nloptr to Imports, add the CRAN/cmake risk.

## Handoff to a medfit session (draft; for when the author opens one)

Read: the PLAN, this ledger, `dev/spike-ram-nloptr.R` (RAM model, analytic gradient, SLSQP; matched lavaan to 3e-7), and the lavaan 0.7-3 report. Deliver: `engine = "native"` in `fit_mediation()` behind the v0 gate (J2). Do not start before the author answers open questions 1, 4 and 6.
