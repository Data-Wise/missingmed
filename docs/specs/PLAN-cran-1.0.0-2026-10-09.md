# PLAN: CRAN submission as 1.0.0

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | DRAFT. Item I reopened as a plan only, gated on E (author, 2026-10-09: "A"). D5 decided: **wait for a medfit CRAN release with the 0.4.0 features, then raise the floor** (author, 2026-10-09: "A"). D6 decided: **the medfit release is 0.7.0 (native SEM)**, not the tagged 0.6.0 (author, 2026-10-09: "B"). D8 decided (T7): **stable core = the four verbs, the three S7 classes, `infer(type = c("mc","mbco"))`, `mbco_d4()`; experimental = `engine = "lavaan"`, `ariv = "own"`, `method = "ipw"`** (author, 2026-10-09: "A"). D7 decided (T1): **E before 1.0.0; C and F conditional on evidence** (author, 2026-10-09: "A"). |
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
| **Check against CRAN dependencies** (scratch library: medfit 0.3.2, lavaan 0.7-3, RMediation 1.6.1; `R CMD check --as-cran --no-manual --timings` on a tarball built from `dev` at `0035cf1`) | **0 errors, 0 warnings, 1 NOTE**: "New submission" plus "Version contains large components (0.8.0.9000)", which a 1.0.0 version removes. Tests 1520 pass, 0 fail, 11 skip, 20 warnings, 20 s. Vignettes rebuild OK. Examples under 1 s in total. Tarball 625 KB (limit 5 MB). | 2026-10-09 run, `rel/check.log` in the session scratchpad |
| The 20 test warnings | all `glm.fit` warnings ("fitted probabilities numerically 0 or 1", "algorithm did not converge") from `test-mbco-convergence.R`, which plants non-convergence on purpose; CRAN does not flag them | same run |
| **Features that need medfit >= 0.4.0** (not on CRAN) | `engine = "regmedint"` stops with "needs medfit >= 0.4.0", and `m_ref` recovery from stored covariate means (an exactly-zero X:M interaction) is skipped. Two tests skip on `packageVersion("medfit") < "0.4.0"`. | `tests/testthat/test-edge-pipeline.R:160-166, 488-494` |

## 3. Not yet checked

| # | Item | How |
|---|---|---|
| U1 | Tarball size, and the installed size NOTE | **Done 2026-10-09:** 625 KB, no size NOTE |
| U2 | Check time on CRAN's limit (under 10 minutes for examples plus tests, vignette build time) | **Done 2026-10-09:** examples under 1 s, tests 20 s, vignettes rebuild OK |
| U3 | Windows, macOS and R-devel results | win-builder (release and devel), mac-builder, `rhub::rhub_check()` |
| U4 | Whether `feature/relicense-lavaan-floor` changes `License:` | read the branch; it is not mine and not a remote branch |
| U5 | CRAN's view of S7 classes registered with `S7::S4_register()` | a check on R-devel and win-builder; no known policy against it |
| U6 | Authors and maintainer fields: `Authors@R` with `cre`, ORCID, copyright holder, `Maintainer` email reachable | read `DESCRIPTION` |
| U7 | `inst/CITATION` matches the CRAN title and version | read the file |

## 4. Tasks

Order: T0, T1, T2 decide scope; T3 to T7 are independent prep and can land as small PRs to `dev`; T8 to T10 are the release.

| # | Task | Acceptance | Verify |
|---|---|---|---|
| T0 | Reopen item I (author decision) DONE 2026-10-09 | the open-items plan says "reopened 2026-10-09" | one line in the plan |
| T1 | Scope freeze DONE 2026-10-09 (D7): E before 1.0.0, committed. C ships enabled if its simulation gate passes before medfit 0.7.0 is on CRAN, otherwise refused as today. F is dropped only if a read-only check shows medfit 0.7.0's lavaan path fixes what `.lav_round_nobs()` works around. | each of C, E, F has its rule | this row |
| T2 | Dependency floors against CRAN | the floor names a CRAN medfit release; no `Remotes:`. **Partly done:** the suite and check pass against CRAN medfit 0.3.2 (section 2); what remains is the decision in D5 | `pak` resolves from CRAN only; `R CMD check` on a clean library |
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
| missingmed 1.0.0 now waits on an unreleased medfit 0.7.0 (D6) | the submission date is set by medfit's native-SEM work (its `.STATUS`: PRs 1 to 5 merged, PR 6 needs an explicit go-ahead, gate S1 still open); missingmed cannot test against 0.7.0 until it exists, and any `Remotes:` pin is not allowed on CRAN | keep missingmed's own CRAN prep ready (T3 to T7); test against medfit `dev` in a scratch library as native SEM lands; submit nothing until 0.7.0 is on CRAN |
| CRAN medfit 0.3.2 lacks the 0.4.0 features | a CRAN missingmed 1.0.0 would ship `engine = "regmedint"` as an engine that errors for every CRAN user, and the exactly-zero-interaction `m_ref` path without covariate means | D5 below |
| `1.0.0` signals stability | the S7 classes and the lavaan engine are young | T7 states what is experimental |
| Spelling WORDLIST hides a typo | a real misspelling ships | review each added word in the PR |
| One CRAN reviewer reads the F7 breaking change as a behavior change between versions | the first release has no prior CRAN version, so no break is visible | none needed |

## 6. Questions for the author (recommendation first)

1. **Reopen I, gated on E and F (recommended).** The plan costs nothing until T8. The alternative is to keep I dropped and treat this file as shelved.
2. **Where do C, E and F land?** Recommended: E before 1.0.0 (it changes interval coverage, which 1.0.0 should not change later); C and F after (C is simulation-gated; F is cleanup behind a medfit release).
4. **D5: submit missingmed 1.0.0 on CRAN medfit 0.3.2, or wait for a medfit CRAN release with the 0.4.0 features? Recommended: wait for medfit**, and raise the floor to that release. The check passes today, but the `regmedint` engine would error for every CRAN user, which reads as a broken feature in a 1.0.0. Submitting a medfit release is a medfit-session task and needs your per-instance permission; its own `.STATUS` lists "missingmed or probmed needing medfit >= 0.4.0" as the open CRAN trigger, so this is that trigger. Alternative: submit now and document `regmedint` as unavailable until medfit >= 0.4.0 reaches CRAN (state it in `?set_md_mediation` and NEWS), which ships earlier and a weaker 1.0.0.
3. **Start T3 now?** Recommended yes: T5 (size and timing) and the CRAN-dependency check are done; T3 (the 148-word WORDLIST) is the largest piece of remaining prep and is independent of the open decisions.
