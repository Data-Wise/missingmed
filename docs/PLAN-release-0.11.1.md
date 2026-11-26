# missingmed 0.11.1 release checklist

The patch candidate starts from `main` at `ce0293e` and incorporates `dev`
at `314b48a`. It includes the R-devel contrast-error test fix ([#120](https://github.com/Data-Wise/missingmed/pull/120))
and the SEM ledger regression controls ([#127](https://github.com/Data-Wise/missingmed/pull/127)).
The candidate retains the v0.11.0 release dependency pins, existing
dependency floors, and the Node.js 24 pkgdown actions on `main`.

## Gates

- Run local `make ci` and Rforge `--as-cran` with RMediation 1.11.2
  (`f5606ae`), S7 1.0.0, and medfit 0.20.0 (`4739e8e`). Build the source
  archive and record its checksum and check results. Check the same archive
  on R 4.1.3 with S7 0.2.2.
- Rehearse all three hosted workflows on the exact candidate on `dev` in a
  private GitHub repository after authorization. Verify that Pages deployment
  is skipped. The upstream workflows do not all trigger for PRs into `main`.
- Open the authorized release PR into `main` and verify its head and diff.
- After an authorized merge, verify the merge tree, all three workflows on
  the resulting `main` SHA, and the Pages deployment.
- After release authorization, tag the verified `main` commit `v0.11.1`,
  publish the GitHub release, and verify its assets, R-universe clean install,
  and live site. The CRAN hold remains.

## Local verification

- R 4.6.2 with the three release pins passed `make ci` and Rforge `--as-cran`.
  Both R CMD check runs reported zero errors, warnings, and NOTEs. The Rforge
  run also checked the PDF manual. Its tests passed 2,659 assertions with 10
  skips and zero failures or warnings.
- R 4.1.3 with RMediation 1.11.2, S7 0.2.2, and medfit 0.20.0 checked the same
  archive with `--no-manual`. The test counts matched R 4.6.2. The check had
  zero errors and warnings and one static-analysis NOTE, identical to the
  v0.11.0 R 4.1.3 check.
- The source archive contains four built vignettes. SHA-256 for
  `missingmed_0.11.1.tar.gz` is
  `54f24f300a90b06fd05868f69c37b38f050145b9863c3780cb46f65e7d03c744`.

## Integration evidence

PR #127 merged into `dev` as `314b48a`. On that push,
[R CMD check](https://github.com/Data-Wise/missingmed/actions/runs/45771016718),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45771016698), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45771016686)
passed. R CMD check reported 2,727 passed assertions, two skips, and zero
failures or test warnings. The pkgdown deploy step was skipped. The release
candidate uses the workflow files from `main`.
