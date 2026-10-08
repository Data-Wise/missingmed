# PLAN: S7 SEM engine and S4 removal (v0.6.0)

| | |
|---|---|
| **Spec** | [SPEC-s7-sem-engine-2026-09-23.md](SPEC-s7-sem-engine-2026-09-23.md) (Q1-Q4, G1-G7) |
| **Grill** | [GRILL-s7-sem-engine-section4-2026-10-07.md](GRILL-s7-sem-engine-section4-2026-10-07.md) |
| **Date** | 2026-10-08 |
| **Status** | GRILLED 2026-10-08 (H1-H5, [GRILL-s7-sem-engine-plan-2026-10-08.md](GRILL-s7-sem-engine-plan-2026-10-08.md)); T0 done 2026-10-08. No package code written. |
| **Target** | v0.6.0 (lavaan engine + S4 `.Defunct()` stubs + `OpenMx` dropped); stubs deleted in 0.7.0 (G7). `run(...)` deprecation moves to 0.7.0 (H1). |

## 1. Review of the spec

Findings from reading the spec against `R/` as of `origin/dev` (0.5.1.9000).
**Blocking** means the plan cannot start the affected task until the author decides.

| # | Finding | Severity | Proposed resolution |
|---|---|---|---|
| F1 | **P3 is still open** and changes the signature that Task 1 builds (`fit_args`, optional `outcome` on glm, `run(...)` deprecation). | **Decided (H1)** | `fit_args` is stored on `MDMediationData` for the **lavaan engine only** in 0.6.0. The `run(...)` deprecation and glm `fit_args` (and optional `outcome` on glm) move to 0.7.0, so 0.6.0 adds no new warning for glm users. |
| F2 | **The S4 removal list is not enumerated.** G7 stubs "the removed S4 exports", but `NAMESPACE` also exports `fit_model`, `lav_mice`, `mx_mice`, `is_fit`, `is_pd`, `is_lav_syntax`, `is_valid_lav_syntax`, `SemResults` and `tidy_mxmodel`/`tidy_logLik` helpers. Whether each is removed, stubbed or kept is undecided. | **Decided (H2)** | **Stub** (`.Defunct()`, naming the replacement): `set_sem`, `run_sem`, `pool_sem`, `fit_model`, `lav_mice`, `mx_mice`. **Delete outright, with a NEWS entry**: `is_pd`, `is_fit`, `is_lav_syntax`, `is_valid_lav_syntax`, the S4 classes (`SemResults`, `SemImputedData`, `PooledSEMResults`) and the OpenMx/logLik tidy helpers. Evidence: the predicates have no callers outside the S4 files; missingmed is a dependency leaf. T0 only confirms the list against `NAMESPACE`. |
| F3 | **Acceptance criterion "strictly more tests" conflicts with removing S4.** `test-s4-legacy.R` (35 `test_that`), `test-tidy_mxmodel.R` and `test-tidy_logLik.R` go away. | **Decided (H4)** | The non-S4 PASS count must not fall below the T0 baseline. Each checkpoint reports three numbers: baseline, S4 tests deleted, tests added. |
| F4 | **Latent-mediator extraction is unverified.** Section 2's probe covers an observed mediator only. Whether `medfit::extract_mediation()` finds `a`/`b` when `M =~ m1 + m2 + m3` is assumed by acceptance criterion 2 and G4. | **Mostly resolved** | Spike 2026-10-08: a latent-mediator lavaan fit (`M =~ m1+m2+m3`, n = 400) converges and `extract_mediation()` returns `a`, `b`, `c_prime` with loadings and `~~` rows. Still to check in T0: the vcov covers the loadings, and `outcome =` is honored. |
| F5 | **Spec target line is stale in section 3**: Q4 still says "errors ... in v0.5.0". | Doc nit | Fix to 0.6.0 in T0. |
| F6 | **`MDMediationData` requires formulas.** `formula_y`/`formula_m` are `class_any` with a validator that insists on formula objects, and `.check_roles()`/`.model_vars()`/`.warn_unimputed()` all read them. The lavaan object has none. | Design gap | Add `model` (character), `outcome` (character) and `fit_args` (list) properties; relax the formula validator when `engine == "lavaan"`; give the helpers a lavaan branch that reads variables from `lavaanify()`. |
| F7 | **`.pool_wald()` rule for `dfcom`** reads the `m_`/`y_` prefixes, and the `~~` rows (Q3) need a second special case. | Known (Q2, Q3) | T4. |
| F8 | **IPW weights must be a data column for `sampling.weights`.** `.ipw_run()` passes a weight vector to `fit_mediation()`. | Detail | T7 appends the weights as a column on the complete-case frame. |
| F9 | **MBCO refuses for lavaan but `infer()` on an `MDMediationResult` already refuses for every engine**, so only the `MDMediationFit` method needs the new engine check. | Detail | T5 touches one branch of `infer()`. |

## 2. Dependency graph

```
T0 decisions + spikes
 └─ T1 object + validation (lavaan, observed)
     └─ T2 run(): lavaan MI fit + G2 convergence
         └─ T3 pool(): engine-aware Wald + ~~ rows
             ├─ T4 infer(): mc works, mbco refuses        ── CHECKPOINT A (observed MI path complete)
             │    ├─ T5 latent mediator (extract + validation + mc)
             │    ├─ T6 IPW + lavaan (G1)
             │    └─ T7 sensitivity_mnar() (G4)            ── CHECKPOINT B (all lavaan features)
             └─────────────────────────────────────────────┐
T8 S4 inventory-driven removal (stubs, tests, OpenMx)  (independent of T1-T7 until T9)
T9 cross-cutting docs (vignettes, migration article)  (needs T1-T8)
T10 run(...) deprecation -> fit_args  MOVED TO 0.7.0 (H1); not in this plan's critical path
T11 release workflow (post-merge, after PR 4)                  ── CHECKPOINT C
```

T8 (S4 removal) is independent of the engine work and can proceed in parallel on its own branch. It must merge **after** the lavaan engine is on `dev`, so that the package is never left with no SEM path (the spec's own reason for G5).

## 3. Tasks

Sizes: XS 1 file, S 1-2, M 3-5. Nothing above M.

### T0: Decisions, inventory, spikes (S, no package code) — DONE 2026-10-08

Scratch scripts only; nothing committed.

| Check | Result |
|---|---|
| lavaan vcov covers the loadings | **Yes.** `extract_mediation()` on `M =~ m1+m2+m3` returns a 19 x 19 vcov whose rows include `M=~m2`, `M=~m3`, the `~~` rows and the `b`/`c_prime` aliases. |
| `outcome =` honored | **Yes.** With two variables regressed on `M`, `outcome = "Y1"` gives `b` 0.3814 and `outcome = "Y2"` gives 0.9391, each equal to lavaan's `b1`/`b2`. Without `outcome`, medfit silently takes the first (Y1), which confirms G3's rationale. |
| `post.check` flags an improper solution | **Yes.** On a planted Heywood case: `converged` TRUE, `post.check` FALSE, min residual variance -0.0017, and lavaan raises exactly one warning ("some estimated ov variances are negative"). `.md_fit_one()` already collects fit warnings, so G2's warn-once is largely the existing machinery plus naming the imputations; the explicit `post.check` call covers cases where lavaan stays silent. |
| Latent extraction; IPW parity | Done in the grill (see the ledger): works; glm vs lavaan `sampling.weights` max difference 8e-16. |
| Non-S4 test baseline | **`devtools::test()`: all files 311 tests / 1281 expectations, 0 failed, 0 skipped, 0 warnings. S4 files (`s4-legacy`, `tidy_mxmodel`, `tidy_logLik`): 38 tests / 156 expectations. Non-S4 baseline: 273 tests / 1125 expectations, 0 failed / skipped / warned.** H4's "must not fall below" refers to these 273 / 1125. |
| H2 list vs `NAMESPACE` | Confirmed, with **one addition**: `n_imp` (S4 generic and `exportMethods`, defined in `R/utilities.R`) is **called by the S7 `set_md_mediation()`**, so it is not S4-only. T8 must keep it (move it out of `utilities.R` before deleting that file). `n_imputations`, `tidy` (broom re-export) and the S7 methods stay. |

### T1: `set_md_mediation(engine = "lavaan")` object and pre-fit validation (M)

- Add `model`, `outcome`, `fit_args` to `MDMediationData` and `set_md_mediation()`; `outcome` required for lavaan (G3). Per H1, `fit_args` is accepted for `engine = "lavaan"` only; passing it with glm errors, pointing to `run(...)` until 0.7.0.
- `.check_engine()` accepts `"lavaan"` for `method = "mi"`; drop the "planned for 0.6.0" hint.
- Lavaan branch of validation: `lavaanify()`; treatment, mediator, outcome present; `mediator ~ treatment` and `outcome ~ mediator` exist (mediator may be latent).
- Errors before any fitting: formulas with lavaan, `model` with glm, missing `outcome`, two outcomes regressed on the mediator with no `outcome`.

**Acceptance:**
- [ ] The object builds for an observed path model and a latent-mediator model.
- [ ] Every error case above fails in `set_md_mediation()`, naming the argument.
- [ ] glm construction and its messages are unchanged.

**Verify:** new `tests/testthat/test-lavaan-spec.R`; `devtools::test(filter = "set-md|lavaan-spec|edge-s7")`.
**Dependencies:** T0. **Files:** `R/set_md_mediation.R`, `R/MDMediationData.R`, `R/run.R` (`.check_engine`), test.

### T2: `run()` fits lavaan per imputation (M)

- A lavaan branch in `.md_engine_call()`: `lavaan::sem(model, data, ...fit_args)` then `medfit::extract_mediation(fit, treatment, mediator, outcome)`.
- Lavaan-aware `.model_vars()`/`.warn_unimputed()`.
- G2: non-convergence refuses, naming the imputations; improper solutions (`post.check`) warn once, naming the imputations. Fold lavaan's own warnings into that message.

**Acceptance:**
- [ ] Observed-variable model: pooled-input `MediationData` list, named like glm's.
- [ ] A planted non-converging imputation errors and names it; a planted Heywood case warns once, names it, and pooling still runs.
- [ ] glm `run()` output is bit-identical to before.

**Verify:** `test-lavaan-run.R`, plus the full existing suite (regression).
**Dependencies:** T1. **Files:** `R/run.R`, test (and `R/MDMediationFit.R` only if an engine slot needs widening).

### T3: `pool()` engine-aware Wald table (S)

- `.pool_wald()`: `dfcom = Inf` for lavaan (Q2); `~~` rows keep estimate and SE, `statistic`/`p_value` NA (Q3); `a`/`b`/`c_prime` aliases stay.
- `m = 1` matches `lavaan::parameterEstimates()` z-tests.

**Acceptance:**
- [ ] Observed lavaan pooled `a`, `b`, `c_prime` equal glm's to 1e-6; SEs within sqrt((n - p)/n).
- [ ] `df` is `Inf`; p-values are normal-theory; at `m = 1` they equal `parameterEstimates()`.
- [ ] `~~` rows: finite estimate and SE, NA statistic and p-value.

**Verify:** `test-lavaan-pool.R` (the glm-parity test is the known-answer test that can fail).
**Dependencies:** T2. **Files:** `R/pool.R`, test.

### T4: `infer()` for lavaan: mc works, mbco refuses (XS)

- `type = "mc"` end to end (test only, if no change is needed).
- `type = "mbco"` on a lavaan `MDMediationFit`: error naming the follow-up spec (Q4).

**Acceptance:** [ ] mc CI on the observed lavaan fit matches the glm CI to the SE ratio tolerance; [ ] mbco errors with a message naming the SEM-MBCO follow-up.
**Verify:** `test-lavaan-infer.R`. **Dependencies:** T3. **Files:** `R/infer.R`, test.

### Checkpoint A: observed MI path

- [ ] Non-S4 suite green; report baseline, S4 tests deleted, tests added (H4); count not below the T0 baseline.
- [ ] `devtools::check()` 0/0/0.
- [ ] A live exercise that can fail, quoted in the PR body (`e2e-before-pr.md`): lavaan vs glm parity on a planted known-answer dataset, and each G2 error/warning path.
- [ ] Author review before T5-T7.

### T5: Latent mediator (M) (scope depends on the F4 spike)

- Validation of `M =~ m1 + m2 + m3` (mediator latent, not a data column; `.check_*` currently require data columns).
- `run() -> pool() -> infer("mc")` on a latent model.

**Acceptance:** [ ] latent model runs through `infer("mc")`; [ ] criterion-2 test passes; [ ] observed-mediator behavior unchanged.
**Verify:** `test-lavaan-latent.R`. **Dependencies:** T4, F4 spike. **Files:** `R/set_md_mediation.R`, `R/run.R`, test.

### T6: IPW with lavaan (M)

- `.ipw_run()` allows lavaan: complete cases, weights appended as a column, `sampling.weights`, `se = "robust.huber.white"` forced (G1).
- A non-robust `se` or sandwich-less estimator in `fit_args` errors.

**Acceptance:** [ ] IPW point estimates equal the glm IPW path to 1e-6 on an observed path model; [ ] a non-robust `se` errors; [ ] glm IPW unchanged.
**Verify:** `test-lavaan-ipw.R`, `test-ipw.R`. **Dependencies:** T4. **Files:** `R/ipw_run.R`, `R/run.R` (`.md_engines`), test.

### T7: `sensitivity_mnar()` on lavaan (S)

- `type = "mc"` works; `type = "mbco"` inherits Q4.
- Latent mediator with `target = NULL` errors before re-imputing and lists the indicators (G4).

**Acceptance:** [ ] mc grid runs on an observed lavaan fit; [ ] latent + `target = NULL` errors listing indicators; [ ] explicit observed `target` works.
**Verify:** `test-lavaan-sensitivity.R`. **Dependencies:** T4 (T5 for the latent case). **Files:** `R/sensitivity_mnar.R`, test.

### Checkpoint B: all lavaan features

- [ ] Every spec section 5 criterion on lavaan passes.
- [ ] Full suite and `devtools::check()` 0/0/0.
- [ ] Author review.

### T8: S4 removal with `.Defunct()` stubs (M, own branch, merges after Checkpoint B)

- **Keep `n_imp`** (S4 generic in `R/utilities.R`, called by `set_md_mediation()`): relocate it before deleting `utilities.R` and keep its `exportMethods` entry. Add a test that `set_md_mediation()` still builds an MI object after the removal.
- Stub `set_sem`, `run_sem`, `pool_sem`, `fit_model`, `lav_mice`, `mx_mice` with `.Defunct()` naming the replacement (G7, H2). Delete `is_pd`, `is_fit`, `is_lav_syntax`, `is_valid_lav_syntax`, the S4 classes and the OpenMx/logLik tidy helpers, with a NEWS entry.
- Every removed export, stubbed or deleted, gets a line in NEWS (symbol, fate, replacement or "none"). The deleted ones are a documented break, not a stub (H2); the review that questioned this (Codex, 2026-10-08) is answered by T9's mechanical coverage check.
- Rewrite DESCRIPTION's `Description:` sentence "A deprecated structural equation modeling interface ('lavaan', 'OpenMx') remains until version 0.6.0" (it names OpenMx and a removed interface).
- Keep `MbcoMIResult`'s `base::print` registration unchanged (H3); remove only OpenMx wording from its comment.
- Remove `OpenMx` from `Imports`, `NAMESPACE` and `DESCRIPTION`'s "deprecated SEM interface" sentence.
- Delete `test-s4-legacy.R` and the OpenMx tidy tests; add a test that each stub errors with its replacement named.
- **Fresh-session print test (H3):** load the installed package in a fresh `Rscript` and print an `MbcoMIResult`, an `MDMediationFit` and an `MDMediationResult`; `load_all()` hides namespace differences.

**Acceptance:** [ ] `OpenMx` gone from `DESCRIPTION`/`NAMESPACE`; [ ] stubs error naming replacements; [ ] `R CMD check` has no OpenMx import notes; [ ] the fresh-session print test passes.
**Verify:** `devtools::document(); devtools::check()`. **Dependencies:** T0 list confirmation; merges after Checkpoint B. **Files:** several in `R/`, `NAMESPACE`, `DESCRIPTION`, tests (the one task that touches many files, but they are deletions).

> If the diff is large, split T8 into 8a (stubs and code deletion) and 8b (tests, `OpenMx` import) inside the same PR.

### T9: Cross-cutting docs (M)

Per H5, each PR already carries its own roxygen, `_pkgdown.yml` and NEWS bullets. T9 is only the prose that spans PRs.

- `supported-models.Rmd`, `s4-migration.Rmd`, `missingmed.Rmd`, `classes_methods.qmd`, `inst/figures/missingmed_uml.svg`; add a lavaan example to `set_md_mediation()` docs.
- `_pkgdown.yml`: remove the "Deprecated (S4)" section or point it at the stubs; any new export must be indexed or the pkgdown CI job fails.
- NEWS, CLAUDE.md (S4 lines in Architecture), `.STATUS`.
- Set DESCRIPTION `Date:` to the release day (recorded miss at v0.4.0).

**Acceptance:** [ ] **coverage check:** every symbol in `git show origin/main:NAMESPACE`'s S4-era exports that is absent or stubbed in the new `NAMESPACE` appears in NEWS and in `s4-migration.Rmd` with its fate and replacement (or "none"); the check is a short script whose output is quoted in the PR body; [ ] `grep -rn 'set_sem\|run_sem\|pool_sem'` hits only stub docs and the migration article; [ ] pkgdown builds; [ ] vignettes build with `eval = TRUE` on new live chunks.
**Dependencies:** T1-T8. **Files:** about 10 doc files; run `doc-update-currency-check` first.

### T10: `run(...)` deprecation into `fit_args` (S) — MOVED TO 0.7.0 (H1)

Not part of the 0.6.0 work. Kept here as the 0.7.0 scope note.

- `run(...)` warns (deprecated) for one cycle and errors on a name repeated in `fit_args`; `sensitivity_mnar()`'s `...` follows.

**Acceptance:** [ ] warning on `run(obj, extra = ...)`; [ ] error on a duplicate name; [ ] sensitivity refits reproduce the original fit options without restating them.
**Dependencies:** T1. **Files:** `R/run.R`, `R/sensitivity_mnar.R`, test.

### T11: Release workflow (S; post-merge, not part of any content PR)

Runs after PR 4 merges. The version bump and the `dev -> main` release PR are release-only changes and stay out of the content PRs.

- Full suite, `R CMD check --as-cran` 0/0/0, `dev/e2e-*` scripts, version bump, release PR (`dev -> main`) per the repo's release process.

**Dependencies:** all. This is `/rforge:release` territory.

### Checkpoint C: release readiness

- [ ] All spec section 5 criteria checked off with quoted evidence.
- [ ] r-universe serves 0.6.0 after the merge to `main`.

## 4. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| F4: medfit's lavaan extractor cannot handle a latent mediator | High: criterion 2 and G4 fail | T0 spike; fall back to an upstream medfit change or drop latent from 0.6.0 (author's call) |
| Improper solutions are common with latent mediators at m >= 20 | Med | G2 warns once; tested with a planted Heywood case |
| `lavaan::sem(sampling.weights)` differs from `.ipw_run()` weights (stabilization, trimming) | Med | T6 parity test at 1e-6 on point estimates |
| S4 removal breaks users with no overlap release | Med | G7 stubs naming replacements; 0.7.0 deletes them |
| `OpenMx` removal exposes a hidden import (`import(OpenMx)` is whole-namespace) | Med | T8 runs `devtools::check()` and greps for unqualified OpenMx symbols |
| pkgdown index misses a changed export | Low, but fails CI | T9 checks `_pkgdown.yml` explicitly |

## 5. PR split (H5)

| PR | Contents | Gate |
|---|---|---|
| 1 | T1-T4 | Checkpoint A |
| 2 | T5-T7 | Checkpoint B |
| 3 | T8 | fresh-session print test (H3) |
| 4 | T9 (cross-cutting prose + the removed-symbol coverage check) | coverage check output in the PR body |
| — | T11 release workflow (`dev -> main`), after PR 4 merges | Checkpoint C |

Each PR carries its own roxygen, `_pkgdown.yml` and NEWS bullets, in one shared `development version` NEWS section.

## 6. Decisions and open items

Resolved in the grill: P3 scope (H1), S4 fate (H2), print registration (H3), test-count wording (H4), PR split (H5, amended below), latent extraction (spike).

Amended after the Codex adversarial review (2026-10-08): T11 moved out of PR 4 into a post-merge release workflow (accepted: the release PR is a separate `dev -> main` PR); H2 is unchanged, with its documentation gap closed by the T9 coverage check instead of more stubs (the deleted symbols have no callers and no replacement to name).

No open T0 items. New T8 hazard found in T0: `n_imp` lives in an S4 file but is used by the S7 path (see T8).
