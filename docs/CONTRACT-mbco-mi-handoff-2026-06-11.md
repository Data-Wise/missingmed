# Handoff — what the Missing Effect MBCO-MI path needs from missingmed

**Date:** 2026-06-11 · **For:** whoever is doing the Phase 0 (S4→S7) work.
**Why you're reading this:** the *Missing Effect* manuscript (`Data-Wise/missing-effect`) has decided
its headline is **inference-led — MBCO-MI vs Monte-Carlo CI**. That makes missingmed's S7 migration the
one gating dependency for a clean handoff to `rmediation`. This note states the exact contract so the
S7 work lands it the first time. **It is not urgent** — the manuscript runs today on a validated
standalone prototype (`research/Missing Effect/code/prototype-d4-mbco.R`); this is the
productionization track, not a blocker.

## The two things the inference layer needs

1. **Named `medfit::MediationData` out of pooling.** `rmediation::mbco()` / `medci()` /
   `ci_mediation_data()` resolve paths **by name** (`a`, `b`, `ab` / NDE, NIE), not positionally. So
   `PooledSEMResults` must be convertible to — or replaced by — a `medfit::MediationData` whose
   `@estimates`/`@vcov` carry **named** mediation parameters. This is the main payoff of the S7
   migration (the scope spec already resolved this contract: `docs/specs/SPEC-missingmed-scope-2026-06-04.md`).

2. **Expose the per-imputation list, not just the pooled object** (this is `Data-Wise/missingmed#2`).
   **MBCO does not commute with Rubin's rules** — you cannot run MBCO on the pooled estimate. The
   Missing Effect derivation (`MEMO-MBCO-MI-derivation-2026-06.md`) settles on **D4 (stacked) MBCO**,
   which needs the *list* of per-imputation fits/`MediationData` to feed `rmediation::mbco()`. So
   alongside `pool_sem()`, missingmed needs an accessor that returns the **list of per-imputation
   named `MediationData`** (the un-pooled `SemResults` payload), plus the imputation count for the
   F/RIV branch. (The other half of #2 is the rmediation-side "weights hook" — out of scope here.)

## What "done" looks like on the missingmed side
- [ ] `run_sem()` → per-imputation results expose **named** `medfit::MediationData` (a/b/ab).
- [ ] A public accessor yields the **list** of those per-imputation `MediationData` (for MBCO), in
      addition to `pool_sem()`'s pooled object (for MC-CI / Wald).
- [ ] Round-trips cleanly into `rmediation::mbco()` and `rmediation::medci()` (the consumers).
- [ ] `rmediation` stays a normal dependency direction (missingmed → rmediation/medfit), no cycle.

## Pointers
- Consumer architecture: `research/Missing Effect/docs/PACKAGE-FIT-2026-06.md` (the 3-package map).
- Why D4/stacked: `research/Missing Effect/MEMO-MBCO-MI-derivation-2026-06.md` (union-null /
  branch-switching on `ab = 0`).
- Estimands & estimator×mechanism matrix: `research/Missing Effect/ESTIMANDS-2026-06.md`.
- Working prototype the production code must match: `research/Missing Effect/code/prototype-d4-mbco.R`
  (D4-MBCO exact match vs `mitml` F/RIV).
- Sim harness that will call all this: `medsim/SPEC-medsim-missingdata-generators-2026-06-11.md`
  (method adapter `medsim_method_mbco_mi()` wraps the prototype now, swaps to missingmed+rmediation later).
