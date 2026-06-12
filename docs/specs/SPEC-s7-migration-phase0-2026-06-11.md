# SPEC — Phase 0: S4 → S7 migration of the MI core

**Status:** 🟢 Active (Phase 0, in progress). **Date:** 2026-06-11. **Author:** Davood Tofighi.
**Parent:** `SPEC-missingmed-scope-2026-06-04.md` (6-phase roadmap; Phase 0 = critical path).
**Consumer contract:** `docs/CONTRACT-mbco-mi-handoff-2026-06-11.md` (what the *Missing Effect*
MBCO-MI study needs out of this migration).

## Goal
Migrate the S4 MI core (`SemImputedData` → `SemResults` → `PooledSEMResults`) to **S7**, so missingmed
can (a) emit a **named `medfit::MediationData`** and (b) **expose the per-imputation list** —
the two things the `rmediation` inference layer needs. Do this *before* adding IPW/GLM so new code
isn't written twice in S4.

**Non-goals (later phases):** IPW estimator (Phase 1), GLM models (Phase 1), MNAR sensitivity
(Phase 3), CRAN polish (Phase 5). New estimators wait until the S7 axes exist.

## Why S7 now (the integration key)
`rmediation::mbco()` / `medci()` / `ci_mediation_data()` resolve paths **by name** and consume a
`medfit::MediationData` (`@estimates`/`@vcov`). S7 is what lets missingmed produce and pass that
object. Two consumer requirements drive the design:

1. **Named pooled `MediationData`** — `pool()` must output a `medfit::MediationData` whose
   `@estimates`/`@vcov` carry **named** mediation parameters (`a`, `b`, `ab`/NDE/NIE). Resolves the
   scope spec's **Open Q3** (a constructor accepting named estimates + vcov).
2. **Per-imputation list accessor** (`missingmed#2`) — **MBCO does not commute with Rubin's rules**
   (Missing Effect `MEMO-MBCO-MI-derivation-2026-06.md`: D4-stacked MBCO). So besides the pooled
   object, expose the **list of per-imputation named `MediationData`** + the imputation count, for
   `rmediation::mbco()` to stack.

## S4 → S7 class mapping
| S4 (today) | S7 (target, names TBD per scope spec) | Carries |
|---|---|---|
| `SemImputedData` | `MDMediationData` | mids/imputed data + model spec + method (`"mi"`/`"ipw"`) + mechanism assumption |
| `SemResults` | `MDMediationFit` | **list** of per-imputation `medfit::MediationData` (named) + meta |
| `PooledSEMResults` | `MDMediationResult` | **pooled named `medfit::MediationData`** + within/between/total vcov |

Keep estimator (MI/IPW) and model (SEM/GLM) as **orthogonal axes** in the S7 design.

## Ordered steps
- **P0.1 — Scaffold.** Add `S7` to Imports; create the three S7 classes (properties only, no logic);
  `set_md_mediation(data, model, method="mi")` constructor (replaces `set_sem`).
- **P0.2 — Fit path.** `run()` loops imputations and produces a **list of named `medfit::MediationData`**
  per imputation (via `medfit::extract_mediation()` / `fit_mediation()`); store in `MDMediationFit`.
- **P0.3 — Pooling → named MediationData.** `pool()` applies Rubin's rules to the named (estimates, vcov)
  and **constructs a `medfit::MediationData`** from the pooled named estimates + vcov (Open Q3). This is
  requirement (1).
- **P0.4 — Per-imputation accessor.** Public accessor returning the `MDMediationFit` list + `m` for
  MBCO (requirement (2), `missingmed#2`).
- **P0.5 — Inference delegation.** `infer(type=c("mbco","mc"))`: `mc` → `rmediation::medci()` on the
  pooled object; `mbco` → `rmediation::mbco()` on the per-imputation list. Promote `rmediation` and
  `medfit` from Suggests → Imports.
- **P0.6 — Output methods + parity.** `print()/summary()/tidy()`; verify against
  `Missing Effect/code/prototype-d4-mbco.R` (the prototype is the spec-by-example).
- **P0.7 — Deprecate S4.** Keep thin S4 shims with `.Deprecated()` for one cycle, then remove.

## Acceptance criteria
- [ ] `run()` yields a **list of named** `medfit::MediationData` (one per imputation).
- [ ] `pool()` returns a **named pooled `medfit::MediationData`** valid as input to
      `rmediation::medci()` / `ci_mediation_data()` (Open Q3 closed).
- [ ] A public accessor exposes the per-imputation list + `m` for `rmediation::mbco()` (`#2` closed).
- [ ] `infer(type="mbco")` and `infer(type="mc")` both run end-to-end and **match the prototype** on
      ≥3 cells (D4-MBCO exact-match vs `mitml` F/RIV).
- [ ] Dependency direction stays missingmed → {medfit, rmediation} (no cycle); `medsim` in Suggests.
- [ ] S4 classes deprecated with shims; tests migrated; `R CMD check` clean.

## Branch / workflow
- `feature/s7-migration` off `dev` (per `.STATUS`). PR to `dev` when acceptance met. `main` protected.

## Pointers
- Contract / consumer: `docs/CONTRACT-mbco-mi-handoff-2026-06-11.md`.
- Scope + phases: `docs/specs/SPEC-missingmed-scope-2026-06-04.md` (Open Q3 resolved here).
- Why D4/stacked + branch-switching: `research/Missing Effect/MEMO-MBCO-MI-derivation-2026-06.md`.
- Prototype to match: `research/Missing Effect/code/prototype-d4-mbco.R`.
- 3-package map: `research/Missing Effect/docs/PACKAGE-FIT-2026-06.md`.

## History
- 2026-06-11 — Phase 0 plan written; folds in the MBCO-MI handoff contract; resolves Open Q3 as
  step P0.3.
