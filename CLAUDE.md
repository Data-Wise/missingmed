# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package is

**missingmed** — "Mediation Analysis with Multiple Imputation for Missing Data" (**v0.2.0**). A **thin orchestration layer** (the missing-data middle): it runs mediation across incomplete data and pools with Rubin's rules — **delegating fitting to `medfit`** and **inference to `RMediation`**, with simulation in `medsim`. **S7-first.**

> **🟢 S7 migration COMPLETE + IPW shipped (v0.2.0, released 2026-06-12).** The S4→S7 rewrite (Phase 0) and the IPW estimator (Phase 1) are released on GitHub, the [pkgdown site](https://data-wise.github.io/missingmed/), and the [Data-Wise r-universe](https://data-wise.r-universe.dev). Next (un-gated, not manuscript-blocking): GLM models, MNAR sensitivity.

## Core workflow (S7)

Four verbs over three S7 classes:
`set_md_mediation()` → `run()` → `pool()` → `infer()` — i.e. `MDMediationData → MDMediationFit → MDMediationResult`.

- **`run()`** fits each imputation via `medfit::fit_mediation()` → a list of **named** `medfit::MediationData`.
- **`pool()`** applies Rubin's rules to the named (estimates, vcov) → a **named pooled** `medfit::MediationData` (valid input to `RMediation::ci_mediation_data()`).
- **`infer(type = c("mc","mbco"))`** — `mc`: Monte-Carlo CI via RMediation; `mbco`: **D4-stacked MBCO** (hosted in `R/mbco_mi.R` — MBCO does **not** commute with Rubin's rules; exact parity with the research prototype). `per_imputation_list()` exposes the per-imputation fits MBCO needs.
- **Two estimators (orthogonal `method` axis):** `"mi"` (default; `data` = `mice::mids`) and `"ipw"` (`data` = `data.frame`; reweighted complete cases, stabilized weights, trimming, `se_type = "sandwich"`).

The **S4 API is deprecated** (`set_sem`/`run_sem`/`pool_sem` + `SemImputedData`/`SemResults`/`PooledSEMResults`) with `.Deprecated()` shims for one cycle.

## Architecture

- `R/MDMediationData.R`, `R/MDMediationFit.R`, `R/MDMediationResult.R` — the three S7 classes (each calls `S7::S4_register()`); `R/zzz.R` runs `S7::methods_register()`.
- `R/set_md_mediation.R`, `R/run.R`, `R/pool.R`, `R/infer.R`, `R/accessors.R` — the S7 pipeline.
- `R/ipw_run.R` — IPW weight estimation + fit; `R/mbco_mi.R` — D4-stacked MBCO.
- `R/methods-output.R` (print/summary/tidy), `R/reexports.R` (`broom::tidy`).
- Legacy S4 (deprecated): `R/SemImputedData.R`, `R/SemResults.R`, `R/PooledSEMResults.R`, `R/fit_model.R`, `R/lav_mice.R`, `R/mx_mice.R`, `R/tidy_*.R`, `R/show.R`, `R/summary.R`, `R/is_*.R`, `R/internal_functions.R`, `R/utilities.R`.

## Dependencies (gotchas)

- Imports: `S7`, **`medfit (>= 0.3.1)`** (needs `weights=`/`se_type=`), **`RMediation (>= 1.4.0)`**, `mice`, `lavaan`, `OpenMx`, `dplyr`, `purrr`, `tibble`, `broom`, `rlang`.
- `DESCRIPTION` `Remotes:` must **name-qualify RMediation**: `RMediation=data-wise/rmediation` (repo is `rmediation`, package is `RMediation` — plain form breaks pak). `Additional_repositories: https://data-wise.r-universe.dev` lets pak resolve the non-CRAN deps.
- Inference namespace is **`RMediation`** (capital), not `rmediation`.

## Build / test / check

```r
devtools::load_all(); devtools::document(); devtools::test(); devtools::check()
```
Needs medfit ≥ 0.3.1 + RMediation installed (from the r-universe). CI uses standard r-lib actions (`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` — the dev `renv.lock` is kept out of CI). pkgdown builds to **`pkgdown-site/`** (not `docs/`, which holds design specs) and deploys via the `gh-pages` branch. `_pkgdown.yml` carries an **explicit `reference:` index** — every new export must be added there or the pkgdown CI job fails; `R CMD check` does not read pkgdown config and will not catch it.

## Ecosystem & manuscript

Part of the **mediationverse** ecosystem (Data-Wise org), coordinated via `~/projects/r-packages/mediation-planning/`. The companion **manuscript** (`~/projects/research/Missing Effect/`) now **runs on `medsim`, not missingmed** — missingmed is the productionized MI/IPW estimation layer, off the manuscript's critical path. Do **not** edit the manuscript repo (it has its own session). missingmed is a **dependency leaf** (imports medfit + RMediation; nothing imports it), so API changes don't cascade.

## Workflow

Multi-branch: `main` (protected — PR-required, no force-push/deletions) ← `dev` (integration) ← `feature/*`. Don't commit to `main` directly.
