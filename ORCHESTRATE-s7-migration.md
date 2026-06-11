# S7 Migration (Phase 0) — Orchestration Plan

> **Branch:** `feature/s7-migration`  **Base:** `dev`
> **Worktree:** `~/.git-worktrees/missingmed/feature-s7-migration`
> **Spec:** `docs/specs/SPEC-s7-migration-phase0-2026-06-11.md`
> **Contract:** `docs/CONTRACT-mbco-mi-handoff-2026-06-11.md`
> **Version Target:** 0.1.0 (dev)

## Objective
Migrate the S4 MI core to three S7 classes so `pool()` emits a NAMED `medfit::MediationData`
and a per-imputation list accessor is exposed; deliver `infer(type=c("mbco","mc"))` end-to-end,
hosting D4-stacked MBCO in missingmed (ported from the research prototype).

## Decisions baked in
- **Orchestrate, not Workflow tool** — sequential dependency chain + review gates.
- **MBCO hosted in missingmed now** — `rmediation::mbco()` is OpenMx-only; port D4-stacking from
  `research/Missing Effect/code/prototype-d4-mbco.R`. Add a TODO to extract to `rmediation` later.
- **mc path via `rmediation::ci_mediation_data()`** on the pooled named MediationData.

## Phase Overview
| Phase | Increment | Parallel? | Gate |
|---|---|---|---|
| 0 | Research: confirm contracts | ⚡ 4 agents | REVIEW |
| 1 | P0.1 Scaffold S7 classes + `set_md_mediation()` | sequential | REVIEW |
| 2 | P0.2 Fit path → list of named MediationData | sequential | — |
| 3 | P0.3 Pool → named MediationData (Open Q3) | sequential | VERIFY |
| 4 | P0.4 Per-imputation accessor (#2) | sequential | — |
| 5 | P0.5 `infer(mbco|mc)` + D4-stacking + dep promote | sequential | VERIFY |
| 6 | P0.6 Output methods + prototype parity | ⚡ 3 agents | VERIFY |
| 7 | P0.7 Deprecate S4 + migrate tests + R CMD check | ⚡ tests | FINAL |
| 8 | P0.8 Vignettes + pkgdown website | ⚡ 2 vignettes | DOCS |

## Phase 0: Research (PARALLEL — read-only, no shared state)
- [ ] 0.1 Re-confirm `medfit::MediationData` constructor + named `@estimates`/`@vcov` (`medfit/R/classes.R:79`)
- [ ] 0.2 Re-confirm `rmediation::ci_mediation_data()` name-resolution contract (`rmediation/R/ci_medfit.R:138`)
- [ ] 0.3 Extract D4-stacking algorithm from `prototype-d4-mbco.R` (`mbco_T`, `ll_med`, `d4_from_stats`, stacked LRT/K)
- [ ] 0.4 Verify `medfit`/`rmediation` are loadable (Remotes/local install); record versions
- **GATE:** synthesize "contracts confirmed" note; confirm before editing code.

## Phase 1: P0.1 Scaffold (SEQUENTIAL)
**Scope:** classes + constructor, properties only, no logic.
- [ ] 1.1 Add `S7` to `Imports` (DESCRIPTION); add `#' @importFrom S7 ...`
- [ ] 1.2 `MDMediationData` (mids/data + model + `method` "mi"/"ipw" + mechanism) — mirror `SemImputedData` slots
- [ ] 1.3 `MDMediationFit` (list of per-imputation named `medfit::MediationData` + meta `m`)
- [ ] 1.4 `MDMediationResult` (pooled named `medfit::MediationData` + within/between/total vcov)
- [ ] 1.5 `set_md_mediation(data, model, method = "mi")` (replaces `set_sem`); reuse `fit_model()`, `model_type()`, `n_imp()`
**Key files:** `R/MDMediationData.R`, `R/MDMediationFit.R`, `R/MDMediationResult.R`, `R/set_md_mediation.R` (NEW); `DESCRIPTION`
- **GATE:** classes documented + `devtools::load_all()` clean before proceeding.

## Phase 2: P0.2 Fit path
- [ ] 2.1 `run()` loops imputations via `lav_mice()` / `mx_mice()`; per imputation build a NAMED `medfit::MediationData` (`extract_mediation()`/`fit_mediation()`), names `a`,`b`,`c_prime`,`m_*`,`y_*`
- [ ] 2.2 Store list + `m` in `MDMediationFit`
**Key files:** `R/run.R` (NEW; supersedes `run_sem`); reuse `lav_mice.R`, `mx_mice.R`, `vcov_lav()`

## Phase 3: P0.3 Pool → named MediationData (Open Q3)
- [ ] 3.1 Migrate Rubin's-rules math from `pool_tidy`/`pool_cov` (`R/SemResults.R:215–278`) onto the named (estimates, vcov)
- [ ] 3.2 Construct a NAMED `medfit::MediationData` from pooled estimates + total vcov → `MDMediationResult`
- **VERIFY:** pooled object is valid input to `rmediation::ci_mediation_data()` (a/b resolve by name)
**Key files:** `R/pool.R` (NEW; supersedes `pool_sem`)

## Phase 4: P0.4 Per-imputation accessor (#2)
- [ ] 4.1 Public accessor returning the `MDMediationFit` list + `m` for MBCO stacking
**Key files:** `R/accessors.R` (NEW)

## Phase 5: P0.5 Inference + D4-stacking (the hosting decision)
- [ ] 5.1 Port D4-stacking from prototype into `R/mbco_mi.R` (NEW): per-imputation MBCO LRT, stacked-LRT/K, `d4_from_stats` → D4, p, r4, nu. Add TODO: extract to rmediation.
- [ ] 5.2 `infer(object, type = c("mbco","mc"))`: `mc` → `rmediation::ci_mediation_data()` on pooled; `mbco` → D4-stacking on the per-imputation list
- [ ] 5.3 Promote `medfit`, `rmediation` Suggests → Imports; `medsim` stays Suggests
- **VERIFY:** both paths run end-to-end; dependency graph stays missingmed → {medfit, rmediation} (no cycle)
**Key files:** `R/mbco_mi.R`, `R/infer.R` (NEW); `DESCRIPTION`

## Phase 6: P0.6 Output methods + parity (PARALLEL: 3 agents)
- [ ] 6.1 `print()` / `summary()` / `tidy()` for the 3 S7 classes (one agent each)
- [ ] 6.2 Parity check vs `prototype-d4-mbco.R` on ≥3 cells (D4-MBCO vs `mitml` F/RIV)
- **VERIFY:** parity within tolerance on ≥3 cells

## Phase 7: P0.7 Deprecate S4 + tests + check (FINAL)
- [ ] 7.1 Thin S4 shims with `.Deprecated()` (`set_sem`/`run_sem`/`pool_sem`) for one cycle
- [ ] 7.2 Migrate `tests/testthat/` (4 files) to S7 classes (PARALLEL); add tests for `infer()`/accessor/pooled-MediationData
- [ ] 7.3 `devtools::document()` + `R CMD check` clean
- **FINAL GATE:** all acceptance criteria checked → PR to `dev`

## Phase 8: P0.8 Vignettes + pkgdown website (DOCS)
**Scope:** user-facing docs for the new S7 API; runs after the FINAL gate (API is stable).
- [ ] 8.1 Getting-started vignette `vignettes/missingmed.Rmd` — full S7 flow:
      `set_md_mediation()` → `run()` → `pool()` → `infer(type="mc")`/`infer(type="mbco")`,
      with the per-imputation accessor shown.
- [ ] 8.2 MBCO-MI vignette `vignettes/mbco-mi.Rmd` — why MBCO doesn't commute with Rubin's rules
      (D4-stacking), mirrors the prototype; cross-links the contract + scope specs.
- [ ] 8.3 Ensure `VignetteBuilder: knitr` in DESCRIPTION; `knitr`/`rmarkdown` already in Suggests.
- [ ] 8.4 pkgdown site: `_pkgdown.yml` (reference index grouped by the 3 S7 classes +
      `set_md_mediation`/`run`/`pool`/`infer`/accessor; articles = the two vignettes).
- [ ] 8.5 GitHub Actions `pkgdown.yaml` (deploy on push to `dev`/`main`) if not present;
      otherwise confirm it builds. `usethis::use_pkgdown_github_pages()` is the shortcut.
- [ ] 8.6 Build locally: `pkgdown::build_site()` clean; `devtools::build_vignettes()` clean.
- **DOCS GATE:** site builds with no missing-topic warnings; vignettes knit end-to-end.
**Key files:** `vignettes/missingmed.Rmd`, `vignettes/mbco-mi.Rmd` (NEW); `_pkgdown.yml` (NEW);
`.github/workflows/pkgdown.yaml`; `DESCRIPTION`

## Friction Prevention
- **Contracts first**: complete Phase 0 before writing any S7 code.
- **Verify location**: confirm CWD is the worktree, not the main repo, before any git op.
- **Deps loadable**: `medfit`/`rmediation` are source-only — install/Remotes them before Phase 2.
- **Names are load-bearing**: estimates/vcov MUST be named (`a`,`b`,`c_prime`,…) or rmediation errors.
- **No autonomous phase starts**: STOP at each GATE and confirm.
- **Don't rewrite Rubin's rules**: migrate `pool_tidy`/`pool_cov` math verbatim.
- **Docs last**: write vignettes/site only after the FINAL gate — the S7 API must be stable so
  examples don't churn. Vignettes must run against the real loaded package (`devtools::load_all()`).

## Acceptance Criteria (from spec)
- [ ] `run()` yields a list of NAMED `medfit::MediationData` (one per imputation)
- [ ] `pool()` returns a NAMED pooled `medfit::MediationData` valid for `ci_mediation_data()` (Open Q3 closed)
- [ ] Public accessor exposes per-imputation list + `m` (#2 closed)
- [ ] `infer("mbco")` (hosted D4) and `infer("mc")` run end-to-end and match the prototype on ≥3 cells
- [ ] Dependency direction stays missingmed → {medfit, rmediation}; `medsim` in Suggests
- [ ] S4 deprecated with shims; tests migrated; `R CMD check` clean
- [ ] Two vignettes knit end-to-end (getting-started + MBCO-MI)
- [ ] pkgdown site builds with no missing-topic warnings; docs deploy workflow green

## Commit Strategy
Conventional commits, one logical group per phase:
`feat(s7)`, `test(s7)`, `refactor(s7)`, `docs(s7)`, `chore(s7)`.

## Verification (per phase)
```r
devtools::load_all(); devtools::document(); devtools::test()
```
```bash
R CMD check   # final gate
```

## Session Instructions
```bash
cd ~/.git-worktrees/missingmed/feature-s7-migration
claude
```
On start, paste:
> Read `ORCHESTRATE-s7-migration.md` and the spec at
> `docs/specs/SPEC-s7-migration-phase0-2026-06-11.md`. Start Phase 0 (research gate).
