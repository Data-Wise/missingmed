# PLAN: CRAN submission as 1.0.0

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | DRAFT, awaiting approval. Reopens a closed decision (section 1). |
| **Follows** | [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md), item I |
| **Owner of the release** | The author. Version bump, `dev` to `main`, tag, GitHub release and the CRAN upload are release engineering and are not done from a feature session without an explicit request. |

## 1. Decision to reopen

[PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md) records "I: Dropped: no CRAN this year", and says dropping I lets missingmed depend on an unreleased medfit through `Remotes:`. Both cannot hold at once with a CRAN submission:

- CRAN requires every hard dependency to be on CRAN (or Bioconductor). `Remotes:` is not honored at install time on CRAN.
- Item E (stack the weight-model score) may need a medfit change. If it does, a CRAN release of missingmed waits for a medfit CRAN release.

**Recommendation: reopen I as a plan only, and gate the submission on E and F.** This file is the checklist; it commits to no date.

## 2. State today (checked 2026-10-09)

| Area | State | Source |
|---|---|---|
| Version | 0.8.0.9000 | `DESCRIPTION` |
| `R CMD check --as-cran` | 0/0/0 locally; a "New submission" NOTE is expected at upload | `cran-comments.md` |
| Dependencies on CRAN | lavaan 0.7-3, medfit 0.3.2, RMediation 1.6.1, mice 3.19.0, S7 0.2.2, sandwich 3.1-3, lifecycle 1.0.5, broom 1.0.13, rlang 1.3.0, tibble 3.3.1, mitml 0.4-5 | crandb, 2026-10-09 |
| `Remotes:` / `Additional_repositories:` | none | `DESCRIPTION` |
| URLs | all 17 return OK | `urlchecker::url_check(".")` |
| Spelling | 148 words flagged, 96 of them in `technical.Rmd`; no `inst/WORDLIST` | `spelling::spell_check_package(".")` |
| `:::` into other packages | none in code (one comment mentions `mice:::barnard.rubin`) | grep |
| Reverse dependencies | none | `cran-comments.md` |
| CI | `check.yml` runs ubuntu-latest only; no OS or R-version matrix | `.github/workflows/check.yml` |
| Skips and examples | one `skip_on_cran` file, one `dontrun`/`donttest` use, `@examples` in 8 R files | grep |
| Local lavaan | 0.7.2, below the `lavaan (>= 0.7-3)` floor, so `load_all()` fails locally; CRAN lavaan reached 0.7-3 on 2026-10-08 | `packageVersion("lavaan")` |
| `NEWS.md` | 743 lines; top section is "development version" | `NEWS.md` |

## 3. Not yet checked

| # | Item | How |
|---|---|---|
| U1 | Tarball size, and the installed size NOTE | `R CMD build .` then `ls -l`; the limit is 5 MB |
| U2 | Check time on CRAN's limit (under 10 minutes for examples plus tests, vignette build time) | `R CMD check --as-cran --timings` |
| U3 | Windows, macOS and R-devel results | win-builder (release and devel), mac-builder, `rhub::rhub_check()` |
| U4 | Whether `feature/relicense-lavaan-floor` changes `License:` | read the branch; it is not mine and not a remote branch |
| U5 | CRAN's view of S7 classes registered with `S7::S4_register()` | a check on R-devel and win-builder; no known policy against it |
| U6 | Authors and maintainer fields: `Authors@R` with `cre`, ORCID, copyright holder, `Maintainer` email reachable | read `DESCRIPTION` |
| U7 | `inst/CITATION` matches the CRAN title and version | read the file |

## 4. Tasks

Order: T0, T1, T2 decide scope; T3 to T7 are independent prep and can land as small PRs to `dev`; T8 to T10 are the release.

| # | Task | Acceptance | Verify |
|---|---|---|---|
| T0 | Reopen item I (author decision) | the open-items plan says "reopened 2026-10-09" | one line in the plan |
| T1 | Scope freeze: decide whether C (MLR), E (weight-score stacking) and F (drop `.lav_round_nobs()`) land before 1.0.0 or after | each of C, E, F is "before" or "after 1.0.0", with the reason | table in this file, section 6 |
| T2 | Dependency floors against CRAN | if E needs medfit changes, the floor names a CRAN medfit release; no `Remotes:` | `pak` resolves from CRAN only; `R CMD check` on a clean library |
| T3 | `inst/WORDLIST` and a clean spelling run | `spelling::spell_check_package(".")` returns no rows; each added word is a real term, not a typo | the command, and a diff review of the WORDLIST |
| T4 | Multi-platform check | win-builder release and devel, mac-builder and an rhub Linux R-devel run all show 0 errors, 0 warnings; notes explained | the result URLs in `cran-comments.md` |
| T5 | Check-time and size gate (U1, U2) | tarball under 5 MB; examples plus tests plus vignettes under CRAN's limits; slow chunks use `eval = FALSE` or a cached result | `--timings` table in the PR |
| T6 | `DESCRIPTION`, `NEWS.md`, `inst/CITATION` for 1.0.0 | the 1.0.0 section lists the breaking changes of 0.8.0.9000 (the F7 sequential default first); `Description:` has no stale text; version stays `0.8.0.9000` until T8 | `git grep` for the old version string; `cran-comments.md` regenerated |
| T7 | API-stability statement | a short section in the package docs naming what 1.0.0 promises: the four verbs, the three S7 classes, `infer(type = c("mc","mbco"))`, `mbco_d4()`; and what is experimental (`engine = "lavaan"`, `ariv = "own"`) | the `lifecycle` badges match the statement |
| T8 | Version bump, `dev` to `main` release PR | `Version: 1.0.0`, full suite and `R CMD check --as-cran` green on the PR branch | CI, plus the counts in the PR body (per `pre-pr-testing.md`: release PRs need the full suite and `pre-release-check.sh`) |
| T9 | CRAN upload | the author submits through the CRAN web form with `cran-comments.md`; the confirmation email is answered by the maintainer | the CRAN confirmation link |
| T10 | After acceptance | tag `v1.0.0` on the merge commit; GitHub release; r-universe serves 1.0.0; pkgdown deploys; `.STATUS` updated | `curl` against the r-universe API, and the pkgdown site |

## 5. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| lavaan floor `>= 0.7-3` is one day old | a CRAN mirror lag can make the floor unsatisfiable for some users | confirm the floor is needed (it was raised for `.lav_round_nobs()` behavior) or lower it to 0.7-2 if the code works there |
| E needs a medfit change | CRAN submission waits for a medfit release, and every medfit write needs per-instance permission | decide in T1; do not start T8 until medfit is on CRAN |
| `1.0.0` signals stability | the S7 classes and the lavaan engine are young | T7 states what is experimental |
| Spelling WORDLIST hides a typo | a real misspelling ships | review each added word in the PR |
| One CRAN reviewer reads the F7 breaking change as a behavior change between versions | the first release has no prior CRAN version, so no break is visible | none needed |

## 6. Questions for the author (recommendation first)

1. **Reopen I, gated on E and F (recommended).** The plan costs nothing until T8. The alternative is to keep I dropped and treat this file as shelved.
2. **Where do C, E and F land?** Recommended: E before 1.0.0 (it changes interval coverage, which 1.0.0 should not change later); C and F after (C is simulation-gated; F is cleanup behind a medfit release).
3. **Start T3 and T5 now?** Recommended yes: they are docs and config only, independent of the open decisions, and T3 is the largest piece of prep work (148 words).
