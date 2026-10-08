# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package is

**missingmed** — "Mediation Analysis with Multiple Imputation for Missing Data" (**v0.5.1.9000**, 0.6.0 in progress). A **thin orchestration layer** (the missing-data middle): it runs mediation across incomplete data and pools with Rubin's rules — **delegating fitting to `medfit`** and **inference to `RMediation`**, with simulation in `medsim`. **S7-first.**

> **🟢 Roadmap complete (v0.3.0).** S7 rewrite + IPW (v0.2.0, 2026-06-12), then GLM family coverage (PR #5) and MNAR sensitivity `sensitivity_mnar()` (PR #6) landed 2026-08. Released on GitHub, the [pkgdown site](https://data-wise.github.io/missingmed/), and the [Data-Wise r-universe](https://data-wise.r-universe.dev). Post-release backlog: `docs/specs/PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` (parked section).

## Core workflow (S7)

Four verbs over three S7 classes:
`set_md_mediation()` → `run()` → `pool()` → `infer()` — i.e. `MDMediationData → MDMediationFit → MDMediationResult`.

- **`run()`** fits each imputation via `medfit::fit_mediation()` → a list of **named** `medfit::MediationData`.
- **`pool()`** applies Rubin's rules to the named (estimates, vcov) → a **named pooled** `medfit::MediationData` (valid input to `RMediation::ci_mediation_data()`).
- **`infer(type = c("mc","mbco"))`** — `mc`: Monte-Carlo CI via RMediation (an `X:M` model needs `treatment_level`, the x in a(b + theta3 x)); `mbco`: **D4-stacked MBCO** (`R/mbco_mi.R` — MBCO does **not** commute with Rubin's rules). `per_imputation_list()` exposes the per-imputation fits MBCO needs. **`ariv = c("fixed", "own")`**, default `"fixed"` (#19): `"fixed"` tests every imputation on the stacked fit's branch; `"own"` is bit-identical to v0.4.0 (and to the research prototype). Returns an **`MbcoMIResult`** (S7, parent `class_double`; index with `r["p"]`/`r[["p"]]`, `$` errors). The exported **`mbco_d4(implist, ...)`** is the same engine on a plain list of data frames. D4-MBCO under MI lives here by decision; RMediation keeps complete-data MBCO.
- **Two estimators (orthogonal `method` axis):** `"mi"` (default; `data` = `mice::mids`) and `"ipw"` (`data` = `data.frame`; reweighted complete cases, stabilized weights, trimming, `se_type = "sandwich"`).

The **S4 API was removed in 0.6.0**: `set_sem`/`run_sem`/`pool_sem`/`fit_model`/`lav_mice`/`mx_mice` are `.Defunct()` stubs in `R/defunct.R` (deleted in 0.7.0); the S4 classes, predicates and OpenMx tidiers are gone. **`engine = "lavaan"`** (`R/lavaan_spec.R`, the lavaan branch of `R/run.R`) takes `model` + `outcome` (+ `fit_args`) instead of formulas; MBCO refuses for it (own spec).

## Architecture

- `R/MDMediationData.R`, `R/MDMediationFit.R`, `R/MDMediationResult.R` — the three S7 classes (each calls `S7::S4_register()`); `R/zzz.R` runs `S7::methods_register()`.
- `R/set_md_mediation.R`, `R/run.R`, `R/pool.R`, `R/infer.R`, `R/accessors.R` — the S7 pipeline.
- `R/ipw_run.R` — IPW weight estimation + fit; `R/mbco_mi.R` — D4-stacked MBCO + `mbco_d4()`; `R/MbcoMIResult.R` — its result class. That class is **not** `S4_register()`ed (fails for a `class_double` parent), so its `print` is registered on `base::print` (the namespace `print` is an S4 generic via the S4 classes (removed in 0.6.0)), and `[`/`[[`/`print` use the functional `` S7::`method<-`() `` form.
- `R/methods-output.R` (print/summary/tidy), `R/reexports.R` (`broom::tidy`).

## Dependencies (gotchas)

- Imports: `S7`, **`medfit (>= 0.3.1)`** (needs `weights=`/`se_type=`), **`RMediation (>= 1.5.0)`**, `mice`, `lavaan`, `sandwich`, `tibble`, `broom`, `rlang`.
- **medfit and RMediation are on CRAN** (0.3.2 and 1.6.1, checked 2026-09-23), so `DESCRIPTION` has no `Remotes:` or `Additional_repositories:`, and pak resolves everything from CRAN. If an unreleased GitHub version is ever needed, `Remotes:` must **name-qualify RMediation**: `RMediation=data-wise/rmediation` (the repo is `rmediation`, the package `RMediation`, and the plain form breaks pak).
- Inference namespace is **`RMediation`** (capital), not `rmediation`.

## Build / test / check

```r
devtools::load_all(); devtools::document(); devtools::test(); devtools::check()
```
Needs medfit ≥ 0.3.1 + RMediation ≥ 1.5.0 installed (both from CRAN). CI uses standard r-lib actions. **No renv** (removed 2026-09-23): the lockfile predated S7, medfit and sandwich and pinned RMediation 1.2.2, below the `>= 1.5.0` floor, so dependencies live in the normal R library, locally and in CI. pkgdown builds to **`pkgdown-site/`** (not `docs/`, which holds design specs) and deploys via the `gh-pages` branch. `_pkgdown.yml` carries an **explicit `reference:` index** — every new export must be added there or the pkgdown CI job fails; `R CMD check` does not read pkgdown config and will not catch it.

## Ecosystem & manuscript

Part of the **mediationverse** ecosystem (Data-Wise org), coordinated via `~/projects/r-packages/mediation-planning/`. The companion **manuscript** (`~/projects/research/Missing Effect/`) now **runs on `medsim`, not missingmed** — missingmed is the productionized MI/IPW estimation layer, off the manuscript's critical path. Do **not** edit the manuscript repo (it has its own session). missingmed is a **dependency leaf** (imports medfit + RMediation; nothing imports it), so API changes don't cascade.

## Workflow

Multi-branch: `main` (protected — PR-required, no force-push/deletions) ← `dev` (integration) ← `feature/*`. Don't commit to `main` directly.
