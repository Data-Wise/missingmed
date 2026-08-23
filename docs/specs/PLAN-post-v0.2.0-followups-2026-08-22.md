# missingmed follow-up plan — v0.2.0 → next

**Drafted:** 2026-08-22 · read-only investigation, no code changed.

**TL;DR:** Do the RMediation audit first — the investigation itself is ~80% of it
(verdict: no breaking change for missingmed; raise the floor to `>= 1.5.0` and re-test
against 1.7.0, ~1–2 h). The rforge parser fix is a small cross-repo PR that can run in
parallel. GLM is the next feature phase — mostly tests + docs, because the plumbing
already exists end-to-end, with **zero medfit blockers**.

---

## Item 1 — RMediation API audit (do first)

### Finding (verified)

- **missingmed's entire runtime RMediation surface is one function**: `ci_mediation_data()`,
  called at `R/infer.R:32` and `R/infer.R:56` as
  `ci_mediation_data(pooled, level = level, type = "MC", n.mc = n.mc)` (imported at
  `infer.R:22`), plus `tests/testthat/test-s7-pipeline.R:68`. Legacy S4 tests call
  `RMediation::tidy()` (`test-tidy_mxmodel.R:37`, `test-tidy_logLik.R:13` — both still
  exported in 1.7.0). `RMediation::mbco()` appears only in comments/docs
  (`R/accessors.R:9`, `R/mbco_mi.R:10`) — never called.
- **What changed 1.4.0 → 1.7.0 on that surface** (from rmediation git history,
  `c9f755b` → `0fad986` → `52d27aa` → v1.7.0):
  - **1.5.0**: first arg renamed `mu` → `object`; positional/value-matching heuristics and
    the silent independence fallback were **removed** in favor of strict name-based
    extraction (`.resolve_path_indices` on `c("a","b")`, `R/ci_medfit.R:140-155`), which now
    errors informatively on unnamed input. missingmed passes the first arg positionally and
    `pool()` produces named `a`/`b`/`c_prime` estimates + dimnamed vcov
    (`R/pool.R:32-49`, `a_path`/`b_path` at `pool.R:55-56`) → **contract satisfied, no break**.
  - **Numerics unchanged for missingmed's input**: the 1.4.0-era source already found `a`/`b`
    by name with named input and used the off-diagonal covariance. The 1.5.0 fix only
    affects unnamed/heuristic paths missingmed never hits.
  - **1.6.1** (`ci()` dispatch arg `mu`→`object`) and **1.7.0** (`pprodnormal3` gauss-quadrature
    fix) don't touch missingmed: it never calls `ci()` by named arg, and `type = "MC"` routes
    to `.compute_ci_mc` (Monte Carlo, 2-variable `ProductNormal`), not the 3-normal CDF.
    `type = "MC"` uppercase is `tolower()`-ed in both eras.
- **Gotcha**: the *installed* library is **RMediation 1.6.1**, not the checkout's 1.7.0
  (`packageVersion` → 1.6.1; medfit installed = 0.3.2). Current test runs exercise 1.6.1.
- **Not verified**: contents of the *released* 1.4.0 tarball (no `v1.4.0` git tag; read the
  1.4.0-era `ci_medfit.R` at commit `c9f755b`), and what version r-universe serves now.

### Options

1. **Raise floor to `RMediation (>= 1.5.0)` (Recommended)** — 1.5.0 is the first version with
   the strict named-extraction contract missingmed's correctness story depends on; below it,
   a name-stripping bug upstream produces a *silently wrong* CI instead of an error. medfit
   floor `>= 0.3.1` is fine as-is (0.3.2 was CRAN-compliance only).
2. Raise to `>= 1.7.0` — matches what users get from r-universe, but overstates the requirement.
3. Keep `>= 1.4.0` — technically works, keeps the silent-fallback risk.

### Concrete steps

1. Install RMediation 1.7.0 into the library (currently 1.6.1).
2. Run `devtools::test()` + `R CMD check`; confirm the 72-test baseline holds against 1.7.0/0.3.2.
3. Add one regression test: strip names from a pooled `MediationData` → `infer(type="mc")`
   must error informatively (locks in the >= 1.5.0 contract).
4. Bump `DESCRIPTION` to `RMediation (>= 1.5.0)` + one NEWS line (next release cycle).
5. Mark the `.STATUS` "audit RMediation API before next release" item resolved.

**Time:** 1–2 h.

### Risks / unknowns

- Test suite not run (read-only session); the "no break" verdict is source-level, step 2 is
  the confirming evidence.
- If r-universe serves a 1.4.0 tarball built before `c9f755b`, the declared floor was never
  installable-correct anyway — raising it resolves that too.

---

## Item 2 — `/rforge:status` parser mismatch

### Finding (verified)

- `status.py` (rforge 2.18.0) is regex-only and, per its own comment, "tightly coupled to
  rforge's `.STATUS` template": anchors are `🎯 CURRENT STATUS`, `✅ JUST COMPLETED`,
  `📋 NEXT ACTIONS`, `⏰ LAST UPDATED`; `progress` comes from `(\d+)%` — missingmed writes
  `progress: 100` with no `%`, so every field parses to `None`.
- **All 7 active packages** (medfit, mediationverse, medrobust, medsim, missingmed, probmed,
  rmediation) use the identical `status:/priority:/progress:/kind:` frontmatter + `##` headers
  — the `key: value` shape is the deliberate ecosystem convention (`kind: package` was added
  ecosystem-wide 2026-07-16). The emoji template matches **zero** packages here.

### Options

1. **Extend rforge's `parse_status_file` to read the frontmatter convention (Recommended)** —
   parse `key: value` lines first (`progress`, `updated`, `status`, `next:` block →
   `next_actions`), keep the emoji regexes as fallback. One parser change fixes all 7
   packages; reshaping 7 curated `.STATUS` files to emoji would fight the ecosystem's own
   machine-readable convention.
2. Reshape `.STATUS` files to emoji — 7 repos of churn, loses the frontmatter other tooling reads.
3. Abandon `/rforge:status` here — least work, least value.

### Concrete steps

1. Locate the rforge source repo (the cache path is a deployed copy — **cross-repo write,
   needs explicit go-ahead**).
2. Add a frontmatter branch to `parse_status_file`: `progress:` → `progress`, `updated:` →
   `last_updated`, `next:` (with continuation lines) → `next_actions`, first `#` title line →
   `current_focus`.
3. Add fixture tests: one emoji-format file, one frontmatter file; assert both parse.
4. Verify across all 7 packages in `~/projects/r-packages/active`.
5. Release via rforge's own pipeline.

**Time:** 1–2 h including tests; independent of Items 1 and 3.

### Risks / unknowns

- rforge source repo location not confirmed (only the 2.18.0 cache copy was read).
- Mapping `##` sections to `just_completed` is ambiguous — scope to the 4 scalar fields first.

---

## Item 3 — next feature phase: GLM models, then MNAR sensitivity

### Finding (verified)

- **GLM is already plumbed end-to-end** — this phase is validation, not construction:
  - `set_md_mediation()` accepts `engine = "glm"`, `family_y`, `family_m`
    (`R/set_md_mediation.R:54-57`); they are S7 properties on `MDMediationData`
    (`R/MDMediationData.R:56-58`); `run()` forwards them per imputation to
    `medfit::fit_mediation()` (`R/run.R:30-40`).
  - **medfit already fits GLMs** — `engine = "glm"` is its *default*, with `family_y`/`family_m`,
    `weights=`, `se_type=c("model","sandwich")` (`medfit/R/fit-glm.R:113-123`).
    **No medfit change needed → no blocker.** (Counterpoint: `glm` is medfit's *only* engine —
    anything else hits `stop("Engine not implemented")` at `fit-glm.R:187` — so the scope
    spec's SEM-via-`run()` lane would need a medfit `lavaan` engine someday; outside these phases.)
  - MBCO is already family-parameterized (`stats::glm(..., family = family_m/family_y)`,
    `R/mbco_mi.R:15-30`).
  - **The gap**: zero non-gaussian tests (no `binomial`/`family` hits in `test-s7-pipeline.R` /
    `test-ipw.R`), no vignette coverage, and one semantic decision — for non-identity links,
    `a*b` and the MC CI live on the **link scale**, which must be documented or gated.
- **MNAR is a real design lift**: the `mechanism` property exists with default `"mar"`
  (`R/MDMediationData.R:60`) but nothing consumes it. The scope spec reserves
  `sensitivity_mnar(...)` and leaves the medrobust-reuse question open — medrobust's bounds
  machinery (`bound_ne*.R`) is adjacent but not a drop-in; the natural MI-side design is
  **delta-adjusted imputation** (mice post-processing offsets over a delta grid → re-run
  pipeline → sensitivity curve). No medfit change required either.

### Options

1. **GLM first (Recommended)** — closes a scope-spec acceptance criterion for roughly a day of
   tests+docs, zero cross-package dependencies, and hardens the exact surface MNAR will re-run
   over a delta grid later.
2. MNAR first — higher novelty, but needs a design spec before any code; doing it over an
   untested GLM surface stacks risk.

### Concrete steps (GLM phase)

1. Test matrix: `{binomial mediator, binomial outcome, poisson outcome} × {mi, ipw}` through
   `set_md_mediation → run → pool → infer("mc")`, plus `infer("mbco")` for MI — assert
   names/dimensions and sane CIs (~12–15 tests).
2. Decide + document link-scale semantics of `a*b` under non-identity links (technical
   vignette; possibly a `message()` on non-gaussian `family_y`).
3. Verify the IPW edge: medfit `weights=` + `se_type="sandwich"` with `binomial` families
   (medfit fits it; missingmed has never tested it).
4. Docs: extend `vignettes/missingmed.Rmd` with one binary-mediator example; NEWS entry.
5. Then write `SPEC-mnar-sensitivity` (delta-adjustment design, `sensitivity_mnar()` verb,
   result class `MDSensitivityResult`, `mechanism="mnar"` semantics) before any MNAR code.

**Time:** GLM ~0.5–1 day; MNAR spec ~half a day; MNAR implementation a separate multi-day phase.

### Risks / unknowns

- Rubin's rules on link-scale coefficients are standard, but pooling *transformed* effects
  (e.g. ORs) is not — keep pooling on the coefficient scale (current behavior) and say so.
- MBCO's D4 with non-gaussian deviances: prototype parity was checked gaussian-only — needs at
  least one binomial sanity check, no external reference available.
- Not verified: whether medfit's sandwich vcov path has its own non-gaussian test coverage.

---

## Sequencing

| Order | Work | Depends on |
|---|---|---|
| 1 | Item 1 audit close-out (install 1.7.0, test, floor bump) | nothing — do now |
| ∥ | Item 2 rforge parser PR (parallel; different repo, needs cross-repo OK) | nothing |
| 2 | Item 3 GLM phase (feature worktree off `dev`) | Item 1 step 2 (test against final dep versions) |
| 3 | MNAR spec, then implementation | GLM phase (re-runs the GLM surface) |

The floor bump (Item 1) and GLM work (Item 3) ship together in the next release (v0.3.0);
Item 2 releases independently on rforge's own cycle.
