# PLAN: close the documentation gaps found in the 2026-10-09 audit

| | |
|---|---|
| **Status** | A, B and C executed 2026-10-09 on `feature/mbco-provider` (gate 22/22); D1, D2, D4 resolved as noted in section 4; D3 resolved 2026-10-09 (restate criterion; SEM-MBCO spec section 11) |
| **Source** | Doc-gap audit of README, vignettes, articles, reference pages, CLAUDE.md, `.STATUS` against the tree at `feature/mbco-provider` (lavaan MBCO) |
| **Harness** | `sh docs/specs/docs-gaps-gates.sh A\|B\|C\|all`: 22 read-only checks, **22 FAIL today** (verified 2026-10-09); each phase ends when its gate is green |
| **Related** | [SPEC-sem-mbco-2026-10-08.md](SPEC-sem-mbco-2026-10-08.md) (T9) |

## 1. Objective

After the lavaan MBCO ships, no page says it is unavailable, every 0.7.0 and 0.8.0
behavior a user can hit (the `fit_args` migration, the convergence stop, the
refusals) is findable from the docs, and a one-page refcard and a cookbook exist.
A claim in the refcard matrix is executed by a test, so it cannot drift.

## 2. Tasks

Sizes: XS one file, S one to three files, M a new page plus a check. Branch: where the
work lands (the lavaan docs ride with the feature, the new pages do not).

### Phase A: statements that are wrong now (branch `feature/mbco-provider`)

| # | Task | Files | Size | Acceptance (must be able to fail) |
|---|---|---|---|---|
| A1 | Replace "SEM (lavaan) ... (planned)" with a pointer to the lavaan article; add the `model =` form to "Without the pipeline" | `vignettes/mbco-mi.Rmd` | XS | Gate A1 x2; the new chunk runs (`eval = TRUE`, small data) |
| A2 | FAQ: MBCO is available for lavaan (ML only); link the lavaan article | `articles/faq.Rmd` | XS | Gate A2 |
| A3 | Drop "cannot do yet (MBCO)" | `articles/supported-models.Rmd` | XS | Gate A3 |
| A4 | Decision tree: "Add `infer(fit, type = "mbco")` (glm or lavaan with ML, MI)" | `articles/choosing-an-analysis.Rmd` | XS | Gate A4 |
| A5 | Migration table row and the "cannot do yet" section: MBCO works for lavaan (ML); refused options named; `sensitivity_mnar()` supports `type = "mbco"` | `articles/s4-migration.Rmd` | S | Gate A5 x2 |
| A6 | Roxygen: `?infer` (lavaan support, refusals, convergence stop), `?sensitivity_mnar` (`type = "mbco"` for lavaan; the sweep aborts naming the rung), `?MbcoMIResult` (produced for lavaan too); then `document()` | `R/infer.R`, `R/sensitivity_mnar.R`, `R/MbcoMIResult.R`, `man/*` | S | Gate A6 x3; `document()` leaves no diff |

**Checkpoint A:** `sh docs/specs/docs-gaps-gates.sh A` green; `pkgdown::check_pkgdown()`
clean; render each edited article (`rmarkdown::render` into a temp dir) with no chunk
error; `R CMD check --as-cran --no-manual` 0/0/0.

### Phase B: never documented (new pages: a separate `feature/docs-refcard` branch off `dev`, after the lavaan MBCO is on `dev`)

| # | Task | Files | Size | Acceptance |
|---|---|---|---|---|
| B1 | **Engine x feature matrix**: rows glm / regmedint / lavaan, columns MI / IPW x mc / mbco / `sensitivity_mnar`, each cell *supported*, *refused (what the error says)*, or *n/a* | `articles/refcard.Rmd` | M | Every cell is executed by B2 |
| B2 | **Matrix test**: for each cell, a supported cell runs and returns the documented class; a refused cell errors with the documented text. Fails if a cell changes without the page | `tests/testthat/test-refcard-matrix.R` | M | Planted defect: flip one cell on the page's data and the test fails |
| B3 | **Error and warning catalog** (in the refcard): condition, cause, fix, and the class where one exists (`md_dots_deprecated`, non-convergence in `run()` and in MBCO, improper solution, option refusals, K < 2, NA in a dropped variable, sparse factor level) | `articles/refcard.Rmd` | S | Each row's message text is a substring asserted in B2's test |
| B4 | FAQ: "My `run()` or `sensitivity_mnar()` call warns about `...`" (the dots deprecation and `fit_args`, with the before/after) | `articles/faq.Rmd`, `articles/choosing-an-analysis.Rmd` | S | Gate B7 x2 |
| B5 | FAQ: "MBCO stopped with 'did not converge'" (cause, what the message names, what to try; near-separation is not refused) | `articles/faq.Rmd` | XS | Gate B8 |
| B6 | Getting started: one paragraph and link for lavaan models | `vignettes/missingmed.Rmd` | XS | Gate B12 |
| B7 | Index the refcard under Guides | `_pkgdown.yml` | XS | Gate B9/B10; `check_pkgdown()` clean |

**Checkpoint B:** `sh docs/specs/docs-gaps-gates.sh B` green; the matrix test passes
and fails when a cell is flipped; suite green; `R CMD check` 0/0/0.

### Phase C: needs the simulation results (after hopper job 4333576 finishes)

| # | Task | Files | Size | Acceptance |
|---|---|---|---|---|
| C-1 | Fold all 40 calibration cells into SEM-MBCO spec section 11; decide the 3.5% band question (see section 4) | `SPEC-sem-mbco-2026-10-08.md` | S | Table complete, 40 cells, failures stated |
| C0 | **Operating characteristics** section: size at the single nulls, conservative at a = b = 0 (numbers from C-1), what it means for power; true of the glm path too | `vignettes/mbco-mi.Rmd`, `articles/lavaan-sem.Rmd` | S | Gate B11; every number traces to a table row |
| C1 | **Cookbook**: eight recipes, each a self-contained runnable chunk: latent-mediator MBCO; sensitivity sweep with MBCO; moderated model via `mbco_d4()`; MI and IPW side by side; the `fit_args` migration; reading `branch_mix` and `ariv`; recovering from a non-converged refit; running a large simulation on hopper (pointer to `dev/` scripts) | `articles/cookbook.Rmd`, `_pkgdown.yml` | M | Gate B13 x2; every chunk runs when the article renders |
| C2 | CLAUDE.md: add `R/mbco_lavaan.R` and the provider seam (`.mm_d4_pool`, `.mm_lav_provider`); `.STATUS` entry | `CLAUDE.md`, `.STATUS` | XS | Gate C1 |
| C3 | `cran-comments.md`: replace "first submission" with the current state | `cran-comments.md` | XS | Gate C2 |
| C4 | `MIGRATION_NOTES.md` (2024 RMediation extraction note, build-ignored): archive or delete (see decisions) | `MIGRATION_NOTES.md` | XS | File moved or removed; `.Rbuildignore` entry removed with it |

**Checkpoint C:** `sh docs/specs/docs-gaps-gates.sh all` green (22/22).

## 3. Order and dependencies

```
A1-A6 ---------------------------> Checkpoint A
B1 -> B2 -> B3 (catalog asserted by the same test)
B4, B5, B6 (independent) ; B7 after B1
hopper results -> C-1 -> C0 ; C1 independent of C-1 except recipe 8 ; C2-C4 independent
```

Phase A first: it removes false statements and costs about an hour. B1/B2 are the
long pole (about half a day: the matrix test needs a runnable example per cell).
Phase C waits on hopper only for C-1 and C0.

## 4. Decisions for the author

| # | Question | Recommendation |
|---|---|---|
| D1 | Refcard as an article, or also a printable one-page PDF? | **Article only** now (it is searchable and carries the executed matrix); a PDF can be rendered from it later |
| D2 | `MIGRATION_NOTES.md`: delete or move to `docs/archive/`? | **Move to `docs/archive/`**: it is history, not guidance, and deleting loses the provenance of the extraction |
| D3 | The calibration band (3.5-6.5%) vs the data: four of 20 cells at 25% missingness sit at or below 3.5% (0.033-0.035) but none is above 5%. Keep the band and reopen, or restate the criterion? | **Restate** as "size at most 6.5% on every cell, and 3.5-6.5% where the null is a single path with the other path strong, reporting conservative cells"; decide after the 40% cells land |
| D4 | Phase B branch: on `feature/mbco-provider` or a separate docs branch? | *Resolved: kept on `feature/mbco-provider`*, because the refcard matrix test needs the lavaan MBCO code, which is not on `dev` yet. Recommendation was: **Separate** (`feature/docs-refcard` off `dev`): new pages are not part of the lavaan MBCO change and can be reviewed alone |

## 5. Risks

| Risk | Mitigation |
|---|---|
| Articles are not built by `R CMD check` (`vignettes/articles` is build-ignored), so a broken chunk ships silently | Checkpoints render every edited article; the cookbook and refcard chunks are the executed tests |
| The refcard matrix drifts from the code | B2 executes every cell; a change to a refusal fails the test |
| Hopper results change the narrative in C0 | C0 is written last and takes its numbers only from the combined table |
| `pkgdown` auto dev mode: a version bump on `dev` overwrites the site root | No version change in this plan |

## 6. Verification summary

| Gate | Command | Expect |
|---|---|---|
| Phase | `sh docs/specs/docs-gaps-gates.sh A\|B\|C` | all PASS |
| Site | `Rscript -e 'pkgdown::check_pkgdown()'` | No problems |
| Package | `R CMD check --as-cran --no-manual` | 0 errors, 0 warnings, 0 notes |
| Articles | render each edited `.Rmd` to a temp dir | no chunk error |
| Suite | `devtools::test()` | 0 failed, strictly more tests than before B2 |
