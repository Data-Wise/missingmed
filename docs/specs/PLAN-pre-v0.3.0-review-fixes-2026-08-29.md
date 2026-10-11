# PLAN — pre-v0.3.0 review fixes (2026-08-29)

Source: adversarial `/code-review high main..dev` after PR #6 merged (dev `9b0cc19`).
Full finding list: session task output `a61d97f941d201b74` (10 findings + 12 lower-severity
notes). This plan sequences the four release-blockers and parks the rest.

**Goal:** dev is releasable as v0.3.0 — no known silently-wrong estimate, no masked
`mice::pool`, version bumped.

**Branch:** `feature/review-fixes` (worktree off dev). One PR, squash to dev.

**Estimate:** ~1.5 h. Steps 1–2 are the bulk (reproducer + fix + test each).

---

## Step 1 — IPW weight/row misalignment (`R/ipw_run.R:38,59`) — ~35 min

Status: PLAUSIBLE (two finders reproduced; verifier did not finish).

**Defect.** `stats::fitted(mod)` has length = rows glm kept. When a predictor of the
missingness model has NAs (treatment with NAs; `weight_formula = ~ X + C` with `C`
incomplete), `p` / `p_num` are shorter than `n`, so `p_num / p` recycles and
`w[!cc] <- NA` indexes the wrong rows. No error, wrong estimates.

1. Reproducer test (must FAIL on dev): `df` with 30 NAs in `X`, `method = "ipw"`;
   expect no "longer object length" warning and `length(w) == nrow(df)`.
2. Fix: replace every `stats::fitted(mod)` in both branches with
   `stats::predict(mod, newdata = dd, type = "response")` (length n; NA where a
   predictor is NA).
3. Then: if any `p[cc]` is NA → `stop()` naming the incomplete missingness-model
   predictor(s). (Complete-case rows with an undefined weight are a spec error, not a
   row to drop silently.)
4. Per-variable list path (finding 5, same file): add a check that
   `names(wf)` are columns of `data` (`stop()` on the first unknown name) — 3 lines,
   fold it in here.

Done when: reproducer passes, `test-ipw*.R` unchanged results otherwise.

## Step 2 — `.mnar_reimpute()` drops imputation settings (`R/sensitivity_mnar.R:192`) — ~30 min

Status: PLAUSIBLE (two finders; a-path 0.2050 vs 0.2020 at `maxit = 20`).

**Defect.** Rebuilds `mice()` from method/predictorMatrix/visitSequence/where/blots/post
but not `maxit`, `blocks`, `formulas`, `ignore`. Rungs are re-imputed under a different
model than the baseline; the "delta = 0 reproduces MAR" guarantee only holds at
`maxit = 5`. With `blocks=` the call errors after printing `target 'NA'`.

1. Reproducer test (must FAIL on dev): `md_mi()` with `maxit = 20`, `delta = 0`,
   `type = "mbco"` → `D4` must equal the MAR baseline (mirrors the existing
   delta-0 test, which passes today only because both sides use maxit 5).
2. Fix: pass `maxit = mids$iteration`, `blocks = mids$blocks`,
   `formulas = mids$formulas`, `ignore = mids$ignore`. Verify each slot name against
   the installed mice (`str(mids)`) before relying on it — mice renames slots across
   versions (memory: probe the library before writing the spec).
3. `.mnar_check_targets()`: `mids$method[v]` returns NA when `blocks` are multivariate;
   `stop()` with a clear message if `is.na(meth)` rather than falling through the
   categorical guard.

Done when: delta-0 parity holds at `maxit = 20`; all 16 MNAR tests pass.

## Step 3 — `pool()` masks `mice::pool` (`R/pool.R:24`) — ~15 min

Status: CONFIRMED (live probe).

**Defect.** Exported S7 generic `pool` with only an `MDMediationFit` method; NAMESPACE
also `importFrom(mice, pool)`. After `library(mice); library(missingmed)`,
`pool(with(imp, lm(...)))` errors "Can't find method".

1. Add a fallback: `S7::method(pool, S7::class_any) <- function(object, ...)
   mice::pool(object, ...)`.
2. Drop `importFrom(mice, pool)` from the roxygen block that emits it (grep
   `@importFrom mice` in `R/`), re-`document()`.
3. Test: `expect_s3_class(pool(with(imp, lm(bmi ~ age))), "mipo")` in
   `test-s7-pipeline.R`.

Done when: no "masks" conflict warning on attach; mipo test passes.

## Step 4 — version bump + release hygiene — ~10 min

Status: CONFIRMED.

1. `DESCRIPTION` `Version: 0.3.0`; NEWS.md top header `# missingmed 0.3.0` (check
   the current header — it may say `(development version)`).
2. `git rm --cached tests/testthat/testthat-problems.rds`; add to `.gitignore` and
   `.Rbuildignore`.
3. Fix the two US-English hits the review found: NEWS.md "favour", RESEARCH doc
   "labelled".
4. `CLAUDE.md`: RMediation floor says `>= 1.4.0`; DESCRIPTION says `>= 1.5.0` —
   align CLAUDE.md.

## Gate (before PR)

- `devtools::test()` — expect ≥ 136 pass / 0 fail (133 + 3 new reproducers).
- `R CMD check --as-cran` — 0E/0W/0N.
- `_pkgdown.yml` reference index unchanged (no new exports; the `class_any` method
  is not an export).
- PR body quotes the three reproducer transcripts (fail on dev → pass on branch).

## Parked (post-v0.3.0; open as issues, do not fix here)

**Status check 2026-10-10, against dev `51d504b` (v0.9.0.9000).** Each item below is tagged
**[RESOLVED]**, **[OPEN]** or **[UNVERIFIED]**. None of the open items was ever filed as an
issue (`gh issue list` was empty). The original text is kept beneath each tag.

- **[RESOLVED]** `R/mbco_mi.R:17` — **SPEC WRITTEN 2026-08-30**: `SPEC-mbco-constrained-models-2026-08-30.md`
  (now CLOSED; `tests/testthat/test-mbco-constrained.R` covers `poly(M, 2)`; the `X:M` question
  was ruled as reading (i): nulling a path drops every term carrying it).
  Confirmed and worse than reported: `Y ~ poly(M, 2) + X` leaves the constrained model
  *identical* to the full model, so T = 0 and the test can never reject. Direction is
  **conservative** (power loss), not anti-conservative as the review said. Parity with
  the research prototype does NOT need re-deriving — old and new agree to the digit on
  the no-interaction case (79.7323). One open question for the author (since answered, see
  above): what the null means when an `X:M` interaction is present.
- **[RESOLVED]** `R/infer.R:27` — `level = 0.95` ignores `object@conf_level`.
  (`level <- level %||% object@conf_level` at `infer.R:89` and `:139`.)
- **[RESOLVED]** `R/pool.R:52` — no `p_value`/df/fmi in the tidy table; pooled object carries
  imputation-1 `data`/`sigma_m`/`sigma_y`. (The tidy table has `statistic`, `df`, `riv`, `fmi`,
  `p_value`; `pooled@data`, `@sigma_m` and `@sigma_y` are set to `NULL`, `pool.R:132-134`.)
- **[RESOLVED]** `R/methods-output.R:91` — tipping point in grid order, not |delta|; never found
  for `mbco`. (`.mnar_tipping` takes the smallest distance from the MAR row and is type-aware.)
- **[OPEN]** `.github/workflows/pkgdown.yaml` — deploys from `dev`; gate on `main`.
  (The deploy step runs on any non-PR push, and the workflow triggers on `[main, dev]`.)
- **[OPEN]** Runtime warning for link-scale `a*b` under binomial families (docs already cover it).
  (No such warning exists in `R/`.)
- Cosmetic:
  - **[OPEN]** lintr step removed with no replacement. (No `.lintr` file and no lint workflow.)
  - **[RESOLVED]** `classes_methods.qmd` teaches the deprecated S4 API. (It now says the S4 API
    was removed in 0.6.0.)
  - **[OPEN]** dead `fits` prop. (`MDMediationFit@fits` is always built as `list()`, at
    `run.R:82` and `ipw_run.R:252`, and never read.)
  - **[RESOLVED]** `mechanism` arg. (Deprecated via lifecycle; the pipeline always estimates
    under MAR.)
  - **[RESOLVED]** `original_data`. (Not dead: used in `run.R` and `infer.R` to expand `Y ~ .`.)
  - **[RESOLVED]** `n_imputations()` duplicates `n_imp()`. (`n_imp` no longer exists.)
  - **[OPEN, minor]** `a*b` hand-computed where `medfit::nie()` exists. (The print method does it
    at `methods-output.R:41`, `:44` and `:54`.)
  - **[UNVERIFIED]** estimator gating string-compared at five sites. (A crude grep for
    `method`/`estimator` comparisons gives about 19 hits; not audited, so the "five" is unconfirmed.)
