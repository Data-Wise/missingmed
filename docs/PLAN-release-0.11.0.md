# missingmed 0.11.0 release plan

Proposed on 2026-11-25. GitHub and Data-Wise R-universe currently serve
missingmed 0.10.0. The candidate starts from upstream `dev` at
`ca4957f8160c2a3d7d0db6aa2681da7781fdda86` plus the website updates.

## Scope and dependencies

- Use **0.11.0** for the SEM MBCO backend change, tighter syntax and fit-option
  validation, branch-specific covariance warnings, R 4.1 fixes, and the S7
  `tidy()` fix. The published 0.10.0 SEM MBCO path still uses lavaan.
- Use the T7 verification combination for the release candidate and website
  build: medfit 0.20.0 (`4739e8e`), S7 1.0.0, RMediation 1.6.1. Preserve the
  medfit 0.14.0 package dependency floor and document that covariance
  retention requires medfit 0.19.0 or later. Keep the RMediation pin in CI and
  the reproducible install instructions.
- T5 was accepted on its recorded pins, and T7 is closed. After PR #117,
  [R CMD check](https://github.com/Data-Wise/missingmed/actions/runs/45721304132),
  [lint](https://github.com/Data-Wise/missingmed/actions/runs/45721304101), and
  [pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45721304007)
  passed on `ca4957f`. Pages deployment was skipped. The broader independent
  D4 sign-off remains open. Review the release with that boundary explicit.
- Keep RMediation 1.6.1 for this candidate. RMediation PR #191 verifies the
  S7 compatibility workflow on its development branch. A dependency upgrade
  needs its own release and missingmed verification.

## Release gates

1. Review the website and plan on a PR into `dev`. Carry forward the corrected
   analysis guide and favicon from [PR #116](https://github.com/Data-Wise/missingmed/pull/116)
   with the 0.11.0 semantics. Keep #116 separate as a 0.10.0 backport.
2. Prepare the release commit. Set `DESCRIPTION` version and date, finalize
   `NEWS.md`, and sweep help, README, site navigation, and stale version claims.
   Build a source archive with vignettes. Run full `make ci`, a clean library
   install and public API smoke tests with the verified combination. Repeat the
   archive tests on the declared R 4.1 floor and a current R release. Exercise
   ordinary SEM refits on the supported medfit floor and ledger-based refits
   on the current pin. Record any warnings or skips against the exact SHA.
3. Run the three hosted workflows on the exact release candidate. Require a
   successful R CMD check, lint and pkgdown build, plus skipped deployment
   during rehearsal. Request approval for the release PR into `main`. Once
   approved and merged, verify its tree matches the tested candidate and
   confirm that the post-merge checks and Pages deployment succeed.
4. With release authorization, tag and publish `v0.11.0` on GitHub. Verify the
   tag, archive, release notes, R-universe build and clean install, and the live
   site's version, analysis guide, SEM article, and favicon. Update `.STATUS`
   and restore the development version on `dev`.

## CRAN

Keep CRAN submission separate. CRAN medfit 0.3.2 is below the 0.14.0 floor
and fails to load with S7 1.0.0. Recheck the CRAN dependency set when a
compatible medfit lands. Require a clean CRAN-only install and current
builder evidence before requesting submission approval.
