# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package is

**missingmed** — "Mediation Analysis with Multiple Imputation for Missing Data" (v0.1.0). Provides **S4** classes and methods to run SEM-based mediation analysis across multiply-imputed datasets and pool the results with Rubin's rules.

Core workflow (S4 pipeline):
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

Part of the **mediationverse** ecosystem (Data-Wise org), coordinated via `~/projects/r-packages/mediation-planning/`. Companion **manuscript**: `~/projects/research/Missing Effect/` (Data-Wise/missing-effect), which studies missing-data mediation more broadly.

**Scope note:** this package implements only the **multiple-imputation (MI)** strand. The manuscript also covers **IPW** and **MBCO vs. Monte-Carlo CIs** — those are not (yet) in this package. Confirm which method a task targets before assuming it lives here.

**Convention note:** missingmed uses **S4**, while the newer ecosystem packages (`probmed`, `medrobust`) standardized on **S7**. Keep this in mind when aligning APIs across the suite; an S4→S7 migration is a possible future direction.

## Workflow

Multi-branch: `main` (protected — PR-required, no force-push/deletions) ← `dev` (integration) ← `feature/*`. Don't commit to `main` directly.
