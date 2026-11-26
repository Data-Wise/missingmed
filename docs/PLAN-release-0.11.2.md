# missingmed 0.11.2 release checklist

The candidate starts from `main` at `f1bcf57065a4b568e477e59357cbe59080bc327c`.
It ships the SEM MBCO fix that identifies each failed null branch and its
dataset in both public APIs and ARIV modes.
[PR #130](https://github.com/Data-Wise/missingmed/pull/130) implemented the
fix, and [PR #133](https://github.com/Data-Wise/missingmed/pull/133) brought it
to `main`.

## Dependency pins

- medfit 0.20.0 at `4739e8e76020cd7d0e5f8f29e9d918c6dd4e6ef8`.
- RMediation 1.11.2 at `f5606ae3e7f365ba5e9c3aa2c0f0622efed297d6`.
- S7 1.0.0 on R 4.6.2 and S7 0.2.2 on R 4.1.3.

## Local verification

- R 4.6.2 passed `make ci` and Rforge `--as-cran`, including the Rforge
  PDF manual check. Both R CMD check runs reported zero errors, warnings,
  and notes. Lint and pkgdown reference checks passed. The reference check
  emitted 15 Pandoc `--mathml` deprecation warnings.
- R 4.1.3 passed the established compatibility check (`--no-manual`) on
  the same archive with zero errors, zero warnings, and the same
  static-analysis NOTE as v0.11.1.
- The additional R 4.1.3 `--as-cran --no-manual` run reported zero errors,
  one warning (missing `qpdf`), and four notes (DOI URI scheme, time
  verification, author metadata formatting, and the same static-analysis
  note).
- All four check runs reported 2,707 test passes, 10 skips, and zero test
  failures or warnings.
- The source archive contains four built vignettes. SHA-256 for
  `missingmed_0.11.2.tar.gz` is
  `f695375935ca48e8b81f0386684318deaceb10d4b7ea3d08ab2eacd2bbd00975`.

## Hosted and publication gates

- After authorization, rehearse R CMD check, lint, and pkgdown on the exact
  candidate on `dev` in a private GitHub repository. Verify that Pages
  deployment is skipped.
- Open the authorized release PR into `main` and verify its head and diff.
- After an authorized merge, verify the merge tree, all three workflows on
  the resulting `main` SHA, and Pages deployment.
- After release authorization, tag the verified `main` commit `v0.11.2`,
  publish the GitHub release, and verify its assets, the R-universe build
  and clean install, and the live site. The CRAN hold remains.
