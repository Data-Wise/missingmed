# missingmed 0.11.0 release plan

Proposed on 2026-11-25. GitHub and Data-Wise R-universe currently serve
missingmed 0.10.0. The candidate starts from upstream `dev` at
`3c96bd48178c5f79d61bc2d60fd1b70ee925b8fb`, which includes the website
updates from [PR #118](https://github.com/Data-Wise/missingmed/pull/118).

## Scope and dependencies

- Use **0.11.0** for the SEM MBCO backend change, tighter syntax and fit-option
  validation, branch-specific covariance warnings, R 4.1 fixes, and the S7
  `tidy()` fix. The published 0.10.0 SEM MBCO path still uses lavaan.
- Use medfit 0.20.0 (`4739e8e`), S7 1.0.0, and RMediation 1.11.2
  (`f5606ae`) for the release candidate and website build. Preserve the
  medfit 0.14.0 package dependency floor and document that covariance
  retention requires medfit 0.19.0 or later. Keep the RMediation pin in CI and
  the reproducible install instructions. Use S7 0.2.2 for the R 4.1
  check because S7 1.0.0 requires R 4.2 or later.
- T5 was accepted on its recorded pins, and T7 is closed. After PR #117,
  [R CMD check](https://github.com/Data-Wise/missingmed/actions/runs/45721304132),
  [lint](https://github.com/Data-Wise/missingmed/actions/runs/45721304101), and
  [pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45721304007)
  passed on `ca4957f`. Pages deployment was skipped. The broader independent
  D4 sign-off remains open. Review the release with that boundary explicit.
- RMediation 1.11.2 is published on [GitHub](https://github.com/Data-Wise/rmediation/releases/tag/v1.11.2)
  and [R-universe](https://data-wise.r-universe.dev/RMediation) at the same
  source SHA. Pin it in all three hosted workflows and both install guides.
  R-universe now defaults to medfit 0.21.0, so CI pins the tested 0.20.0 commit
  and the guides use its matching tag.

## Release gates

1. Complete: the website and plan merged into `dev` in PR #118. Carry forward the corrected
   analysis guide and favicon from [PR #116](https://github.com/Data-Wise/missingmed/pull/116)
   with the 0.11.0 semantics. Keep #116 separate as a 0.10.0 backport.
2. Prepare the release commit. Set `DESCRIPTION` version and date, finalize
   `NEWS.md`, and sweep help, README, site navigation, and stale version claims.
   Build a source archive with vignettes. Run full `make ci`, a clean library
   install and public API smoke tests with the verified combination. Repeat the
   archive tests on the declared R 4.1 floor and a current R release. Exercise
   ordinary SEM refits on the supported medfit floor and ledger-based refits
   on the current pin. Record any warnings or skips against the exact SHA.
   RMediation 1.6.1 failed the direct Monte Carlo call on R 4.1.3
   with S7 0.2.2 and medfit 0.20.0. Verify the same call, installed public
   API smoke, and the full archive check with the published RMediation 1.11.2.
3. Run the three hosted workflows on the exact release candidate. Require a
   successful R CMD check, lint and pkgdown build, plus skipped deployment
   during rehearsal. Request approval for the release PR into `main`. Once
   approved and merged, verify its tree matches the tested candidate and
   confirm that the post-merge checks and Pages deployment succeed.
4. With release authorization, tag and publish `v0.11.0` on GitHub. Verify the
   tag, archive, release notes, R-universe build and clean install, and the live
   site's version, analysis guide, SEM article, and favicon. Update `.STATUS`
   and restore the development version on `dev`.

## Local release verification

The installed R-universe RMediation 1.11.2 source archive reports
`f5606ae3e7f365ba5e9c3aa2c0f0622efed297d6`, the GitHub release commit.
Both archive checks used medfit 0.20.0 at
`4739e8e76020cd7d0e5f8f29e9d918c6dd4e6ef8` and the same missingmed
0.11.0 source archive with four vignettes. Archive SHA-256
`96b44efdf1166f2b0494d6fbc8b1c73b195fd7638f0745f2b76d89ea720682e9`.

| R | S7 | R CMD check | Testthat |
| --- | --- | --- | --- |
| 4.1.3 | 0.2.2 | 0 errors, 0 warnings, 1 S7 static-analysis note | 2,503 passed, 10 skipped |
| 4.6.2 | 1.0.0 | 0 errors, 0 warnings, 0 notes | 2,503 passed, 10 skipped |

Both checks rebuilt all four vignettes. Testthat reported zero failures and
warnings. The skips were eight CRAN opt-outs, the optional `regmedint`
comparison, and the source-only refcard check. The R 4.1.3 check used
`--no-manual`. The R 4.6.2 check also used `--as-cran` with remote
CRAN incoming probes disabled. An additional R 4.1.3 `--as-cran` run
used the installed `qpdf` and disabled the remote clock probe. It also
rebuilt all four vignettes with zero errors or warnings. Its three
notes cover legacy DOI URL checks, author metadata formatting, and the
same S7 static analysis.

- On both R versions, the direct Monte Carlo call passed, as did installed
  `infer(type = "mbco")` and `mbco_d4()` in both ARIV modes and
  `tidy(pool(fit))`. The medfit 0.14.0 floor control passed both public APIs
  through the guarded affine path on R 4.6.2 with S7 0.2.2.
- The current-R source suite passed all 2,598 assertions. `make ci` passed
  with zero check errors, warnings, notes, or lints. The reference index
  passed. The local site built 50 pages and passed 1,963 link and asset
  checks, 459 fragment checks, and two manifest icon checks.
- pak resolved the three pins for the archive, development install, and
  workflow dependency sets. actionlint passed on the three workflows.

The hosted workflow rehearsal remains pending.

## CRAN

Keep CRAN submission separate. CRAN medfit 0.3.2 is below the 0.14.0 floor
and fails to load with S7 1.0.0. Recheck the CRAN dependency set when a
compatible medfit lands. Require a clean CRAN-only install and current
builder evidence before requesting submission approval.
