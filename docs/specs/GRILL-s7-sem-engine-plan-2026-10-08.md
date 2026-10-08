# GRILL: SEM engine plan (PLAN-s7-sem-engine-2026-10-08.md)

| | |
|---|---|
| **Target** | [PLAN-s7-sem-engine-2026-10-08.md](PLAN-s7-sem-engine-2026-10-08.md) |
| **Date** | 2026-10-08 |
| **Status** | Done: H1-H5 locked; folded into the plan and spec 2026-10-08 |

## Evidence gathered

- F4 spike (2026-10-08, scratch): lavaan latent-mediator fit (`M =~ m1+m2+m3`, n = 400) converges, `post.check` TRUE; `medfit::extract_mediation(f, treatment, mediator, outcome)` returns `a`, `b`, `c_prime` plus loadings and `~~` rows. Not yet checked: vcov covers the loadings; `outcome =` is honored.

## Decision ledger

| # | Question | Decision | Rejected |
|---|---|---|---|
| H1 | When does P3's `fit_args` land? | **Option B**: `fit_args` for the lavaan engine only in 0.6.0; the `run(...)` deprecation and glm `fit_args` move to 0.7.0 with the stub deletion. T10 leaves the 0.6.0 plan. | A: full P3 in 0.6.0 (third breaking change in one release); C: reject P3 (sensitivity refits must restate options) |
| H2 | Fate of S4-adjacent exports (F2) | **Option B**: stub the workflow functions (`set_sem`, `run_sem`, `pool_sem`, `fit_model`, `lav_mice`, `mx_mice`) with `.Defunct()`; delete the predicates (`is_pd`, `is_fit`, `is_lav_syntax`, `is_valid_lav_syntax`), the S4 classes and the OpenMx/logLik tidy helpers outright, with a NEWS entry. Evidence: the predicates have no callers outside the S4 files; missingmed is a dependency leaf. | A: stub every export (about 10 stub Rd pages, deleted again in 0.7.0); C: keep the lavaan-syntax predicates live (T1 uses `lavaanify()`, so no caller) |
| H3 | `import(OpenMx)` removal vs `MbcoMIResult`'s `base::print` registration | **Option A**: keep the `base::print` registration unchanged; T8 adds a fresh-session test (installed package, fresh `Rscript`) that prints an `MbcoMIResult`, an `MDMediationFit` and an `MDMediationResult`. `load_all()` tests hide namespace differences, so they cannot be the check. | B: move to a plain `S7::method(print, ...)` (reintroduces the registration path that failed for `class_double`); C: rely on `R CMD check` (silent-failure case) |

## Evidence added

- IPW parity spike (2026-10-08, scratch, n = 500, MAR on M): glm IPW and `lavaan::sem(sampling.weights =)` on the same complete cases agree to 8e-16 (`a` 0.5034498, `b` 0.4482354, `c_prime` 0.0008996). T6's 1e-6 criterion is safe.
| H4 | Wording of the test-count criterion (F3) | **Option A**: the non-S4 PASS count must not fall below the T0 baseline; each checkpoint reports three numbers: baseline, S4 tests deleted, tests added. | B: final total must exceed today's total (pressure to pad); C: drop the count criterion (loses the guard against deleting a non-S4 test during S4 removal) |
| H5 | PR split and where docs go | **Option B**: 4 PRs: (1) T1-T4, (2) T5-T7, (3) T8, (4) T9 prose + T11 release gate. Each PR carries its own roxygen, `_pkgdown.yml` and NEWS bullets (one shared `development version` NEWS section, so no heading collisions). | A: one PR per task (~10 CI cycles, NEWS conflicts); C: two PRs (a pkgdown miss blocks everything) |

Note: the recorded hook claim that `tests/testthat.R` is missing is stale; it was added in #11 (`c9e5b2b`), so `R CMD check` runs the suite.

## Open Questions

- Three T0 checks remain (not decisions): the lavaan vcov covers the loadings; `extract_mediation(outcome =)` is honored; `post.check` flags a planted improper solution.
- Candidate branches not grilled (small, fit inside T2/T3): the G2 improper-solution threshold; `~~` rows with `conf_int = TRUE`.

## Amendments after the Codex adversarial review (2026-10-08)

- **H5 amended:** PR 4 is T9 only; T11 (version bump, `dev -> main` release PR) becomes a post-merge release workflow. Reason: the release PR is a separate PR by the repo's workflow, so listing it in PR 4 blurred the order.
- **H2 reaffirmed, gap closed:** the review asked to stub the deleted predicates and classes. Kept as decided (no callers; classes cannot be stubbed; leaf package), but T8/T9 now require every removed export to appear in NEWS and the migration article with its fate and replacement, checked by a script against `origin/main`'s `NAMESPACE`.

## T0 results (2026-10-08)

All three remaining spikes passed (vcov covers loadings; `outcome =` honored; `post.check` flags a planted Heywood case). Non-S4 baseline: 273 tests / 1125 expectations, all passing. New hazard: `n_imp` is defined in `R/utilities.R` but called by `set_md_mediation()`, so T8 must keep it. Details in the plan's T0 section.
