# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package is

**missingmed** — "Mediation Analysis with Multiple Imputation for Missing Data" (v0.1.0). A **thin orchestration layer**: the missing-data middle that runs SEM-based mediation across multiply-imputed datasets and pools with Rubin's rules — delegating fitting to **medfit** and inference to **rmediation**, and simulating via **medsim**.

> **🟢 Phase 0 (S4 → S7 migration) in progress** — see `docs/specs/SPEC-s7-migration-phase0-2026-06-11.md`. The S4 pipeline below is being migrated to S7 so `pool()` emits a **named** `medfit::MediationData` and a **per-imputation list** accessor is exposed (required by the companion manuscript's MBCO-MI path; see Scope note). Do Phase 0 before adding IPW/GLM so new code isn't written twice in S4.

Core workflow (current S4 pipeline → S7 targets `MDMediationData → MDMediationFit → MDMediationResult`):
`SemImputedData` (imputed data + model) → `set_sem()` → `run_sem()` → `SemResults` (per-imputation fits) → `pool_sem()` → `PooledSEMResults` (pooled estimates). Integrates **mice** (imputation), **lavaan** and **OpenMx** (SEM), and **RMediation** (indirect-effect CIs).

## Architecture

- `R/SemImputedData.R`, `R/SemResults.R`, `R/PooledSEMResults.R` — the three S4 classes
- `R/fit_model.R`, `R/lav_mice.R`, `R/mx_mice.R` — fitting across imputations (lavaan / OpenMx)
- `R/tidy_*.R`, `R/print.R`, `R/show.R`, `R/summary.R` — S4 output methods
- `R/is_*.R`, `R/internal_functions.R`, `R/utilities.R` — validators/helpers

## Build / test / check

```r
devtools::load_all()      # develop
devtools::document()      # roxygen2 -> man/, NAMESPACE
devtools::test()          # testthat
devtools::check()         # R CMD check
```
`renv` manages dependencies (`renv::restore()`). A `Makefile` is present for common targets.

## Ecosystem & manuscript

Part of the **mediationverse** ecosystem (Data-Wise org), coordinated via `~/projects/r-packages/mediation-planning/`. Companion **manuscript**: `~/projects/research/Missing Effect/` (Data-Wise/missing-effect).

**Scope / role note:** the manuscript's headline is now **inference-led — MBCO-MI vs Monte-Carlo CI**, so missingmed's job is the **MI estimation + Rubin's-rules pooling** that feeds `rmediation`'s inference (`mbco()` / `medci()`); **IPW** is a thin robustness wrapper (manuscript appendix), and the MBCO/MC-CI machinery itself lives in **rmediation**. Two consumer requirements drive Phase 0: (1) `pool()` must emit a **named** `medfit::MediationData`; (2) expose the **per-imputation list** for MBCO — because **MBCO does not commute with Rubin's rules** (D4-stacked MBCO). Details: `docs/CONTRACT-mbco-mi-handoff-2026-06-11.md` + scope spec `docs/specs/SPEC-missingmed-scope-2026-06-04.md`.

**Convention note:** missingmed is **S4 today**, mid-migration to **S7** (Phase 0, active) to match the newer ecosystem packages (`probmed`, `medrobust`) and the shared `medfit::MediationData` contract. Keep new code S7-first.

## Workflow

Multi-branch: `main` (protected — PR-required, no force-push/deletions) ← `dev` (integration) ← `feature/*`. Don't commit to `main` directly.
