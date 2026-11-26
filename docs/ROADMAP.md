# missingmed roadmap

Updated 2026-11-26. See the [T5 plan](../tasks/plan.md#current-state-2026-11-24)
for evidence and the [status file](../.STATUS) for the current handoff.

## Shipped

- v0.2.0 S7 rewrite + IPW (2026-06-12); GLM families (PR #5) and `sensitivity_mnar()` (PR #6) (2026-08).
- [v0.11.0](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.0)
  released 2026-11-25.
  It uses medfit for SEM MBCO refits. See [NEWS](../NEWS.md) and the
  [release checklist](PLAN-release-0.11.0.md) for release details and checks.

- [v0.11.1](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.1)
  released 2026-11-26 from `main` at `42b4805` ([PR #128](https://github.com/Data-Wise/missingmed/pull/128)).
  It includes the R-devel contrast-error test fix and SEM ledger regression
  controls. See the [release checklist](PLAN-release-0.11.1.md).

- [v0.11.2](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.2)
  released 2026-11-26 from `main` at `af2c6ec` ([PR #136](https://github.com/Data-Wise/missingmed/pull/136)).
  It ships the SEM MBCO diagnostic that identifies each failed null branch and
  its dataset in both public APIs and ARIV modes. See the
  [release checklist](PLAN-release-0.11.2.md).

## R-universe verification for v0.11.2

[Data-Wise R-universe](https://data-wise.r-universe.dev/missingmed) published
v0.11.2 from `af2c6ec`. All nine targets reported `OK`, covering source and
vignettes, Linux release and devel, macOS release and oldrel, Windows release,
oldrel and devel, and Wasm. Each of the seven native R CMD check jobs reported
zero errors, warnings, or notes, with 2,707 test passes and 10 skips.

The published source archive matched its advertised SHA-256
(`b143d9c87696fcd93ea6d6fa5888811a73cdcd36f8c35afcfca2ad45e1f03d2f`).
It installed and loaded in a fresh R 4.6.2 library with medfit 0.20.0,
RMediation 1.11.2, and S7 1.0.0. The installed package recorded `af2c6ec`
as its source commit.

The hosted tooling logged a Node `Buffer()` deprecation during artifact
download and a 404 for the Bioconductor 3.25 workflows index. The initial
pkgdown probe returned 404 and the live site probe returned 200.
Publication succeeded.
[R-universe build](https://github.com/r-universe/data-wise/actions/runs/45893877330)

## R-universe verification for v0.11.1

[Data-Wise R-universe](https://data-wise.r-universe.dev/api/packages/missingmed)
published v0.11.1 from `42b4805`. All nine targets reported `OK`: source and
vignettes, Linux release and devel, macOS release and oldrel, Windows release,
oldrel and devel, and Wasm. The seven native R CMD check jobs each reported
2,659 passing assertions, 10 skips, and zero failures or test warnings.
The downloaded R-universe source archive matched the published SHA-256 and
installed and loaded in a fresh R 4.6.2 library with medfit 0.20.0,
RMediation 1.11.2, and S7 1.0.0.

The [R-universe build log](https://github.com/r-universe/data-wise/actions/runs/45782240792)
records a Node `Buffer()` deprecation in its artifact-download step and a 404
from the Bioconductor 3.25 workflows index during metadata collection. Its
initial pkgdown URL probe returned 404, then the live site returned 200. These
messages came from the hosted build tooling and publication succeeded.

## Website

[PR #139](https://github.com/Data-Wise/missingmed/pull/139) merged into
`main` at `21fd72c` and closed [#104](https://github.com/Data-Wise/missingmed/issues/104)
and [#109](https://github.com/Data-Wise/missingmed/issues/109). Both SEM MBCO
APIs now preserve medfit warning classes and use the same format for improper
fits in both ARIV modes. Post-merge
[R CMD check](https://github.com/Data-Wise/missingmed/actions/runs/45906461654),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45906461639), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45906461626)
all passed on `21fd72c`. R CMD check reported 2,820 passes, two skips, and zero
test failures or warnings.

[Pages deployed](https://github.com/Data-Wise/missingmed/actions/runs/45906781402)
`gh-pages` commit `a9fd674`. The live
[`infer()` reference](https://data-wise.github.io/missingmed/reference/infer.html),
[`mbco_d4()` reference](https://data-wise.github.io/missingmed/reference/mbco_d4.html),
and [SEM guide](https://data-wise.github.io/missingmed/articles/lavaan-sem.html)
matched the deployed files byte for byte. GitHub's generated Pages build
emitted one nonblocking Node.js 20 warning from `actions/upload-artifact@v4`.

[PR #137](https://github.com/Data-Wise/missingmed/pull/137) merged into
`main` at `1531384` with the same tree as `fe566e6`. Post-merge
[R CMD check](https://github.com/Data-Wise/missingmed/actions/runs/45898363039),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45898363035), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45898363071)
passed with no Node.js 20 warnings. R CMD check reported 2,775 passes, two
skips, and zero errors, warnings, or notes.

GitHub's automatically generated [Pages workflow](https://github.com/Data-Wise/missingmed/actions/runs/45898759296)
passed and published `gh-pages` commit `53e85a7`. Its build job emitted one
Node.js 20 deprecation warning from `actions/upload-artifact@v4`. The
[live technical vignette](https://data-wise.github.io/missingmed/articles/technical.html)
matched the deployed HTML byte for byte and contained both corrected HTTPS
DOI links.

The [public pkgdown site](https://data-wise.github.io/missingmed/) includes
the [C5 diagnostic documentation](#c5-diagnostic-on-main). The v0.11.2
[release-triggered pkgdown build](https://github.com/Data-Wise/missingmed/actions/runs/45892379653)
passed and the [Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45892892935)
published `gh-pages` commit `efb103d`. The live homepage and
[v0.11.2 changelog](https://data-wise.github.io/missingmed/news/index.html)
matched the deployed files byte for byte.

For the v0.11.1 release, the [post-merge pkgdown build](https://github.com/Data-Wise/missingmed/actions/runs/45773976381)
and [Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45774376667)
passed. The live homepage, changelog, and cookbook matched the deployed files.

[PR #125](https://github.com/Data-Wise/missingmed/pull/125) refreshed the
cookbook, tutorials, and guides and merged into `main` as `eba33d4`.
The [post-merge pkgdown build](https://github.com/Data-Wise/missingmed/actions/runs/45763654984)
passed. The [Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45763991106)
published `gh-pages` commit `407ca66`. All seven updated articles matched
the deployed HTML byte for byte, including the
[live cookbook](https://data-wise.github.io/missingmed/articles/cookbook.html).

[PR #121](https://github.com/Data-Wise/missingmed/pull/121) merged
into `main` as `81880e0`. Its [post-merge pkgdown build](https://github.com/Data-Wise/missingmed/actions/runs/45757386943)
and [Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45757715117)
passed. The updated installation links were verified on the live homepage
and Getting Started article.

[PR #123](https://github.com/Data-Wise/missingmed/pull/123) moved the checkout
and Pages deploy actions to Node.js 24 and merged into `main` at `0a72156`.
Its post-merge pkgdown build and deploy step passed without Node.js 20
deprecation warnings. Pages published `gh-pages` commit `a2ff957`.
[Pkgdown run](https://github.com/Data-Wise/missingmed/actions/runs/45760884890) ·
[Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45761259587) ·
[Receipt in PR #124](https://github.com/Data-Wise/missingmed/pull/124)

The guide corrections and favicon proposed in PR #116 are present on `main`
and the live site. The README links directly to the updated guide.
[PR #116](https://github.com/Data-Wise/missingmed/pull/116) ·
[Live Choosing an analysis guide](https://data-wise.github.io/missingmed/articles/choosing-an-analysis.html)

## T5 evidence and owner decision

The owner **accepted T5 on 2026-11-25** on missingmed `8dac15d` and medfit
v0.19.0 `2c334734`. The [checklist](../tasks/todo.md) records the evidence and
the [plan](../tasks/plan.md#acceptance-checkpoint-and-downstream-tasks) records
the decision.

| Gate | Owner | State |
|---|---|---|
| P3: improper-null real-case evidence | author | Met 2026-10-26 (ruling B, gate amended): simulated seed 45 qualifies, origin SIMULATED; mechanism check in the worktree note. Collaborator route, R3 and R5 dropped; route plan `docs/PLAN-p3-raw-data-routes-2026-10-24.md` is historical. Limits in `tasks/plan.md` P3 |
| D4 independent closure | Owner | Closed 2026-11-26 on missingmed `39c6012` and medfit v0.19.0 `2c334734` after independent review. See the [closure evidence](https://github.com/Data-Wise/missingmed/blob/2baba8c5baf8da30b9db46c72b09d588021baf92/tasks/plan.md#d4-independent-closure). |
| D1–D4 integration | medfit | Pinned v0.19.0 (`2c334734`) includes narrowed covariance retention. |
| D5 integration | Codex | Implemented locally at `8dac15d`. Pinned tests cover both APIs, both ARIV modes, and refusal of invalid ledgers. |
| D5 qualifying-case replay | Codex | The five-imputation replay pooled with the recovered single start for imputation 3's `a = 0` null. All 18 same-engine fits agreed on raw LRs. The shipped-default check exercised native retries separately. |
| T5 acceptance | Owner | Accepted 2026-11-25 after the P2 findings disposition and Opus follow-up. |

## D4 closure on dev

[PR #131](https://github.com/Data-Wise/missingmed/pull/131) recorded the passing
C5, `anova()`, and old-design replays and squash-merged into `dev` as `2baba8c`.
The post-merge [R-CMD-check](https://github.com/Data-Wise/missingmed/actions/runs/45875372666),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45875372576), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45875372667)
workflows all passed on that SHA. R-CMD-check reported 2,775 passes, two skips,
and zero test failures or warnings. The pkgdown run skipped Pages deployment.

## R-devel follow-up

[PR #120](https://github.com/Data-Wise/missingmed/pull/120) keeps the
contrast-error assertion tied to imputation 2. Hosted Linux and Windows
R-devel checks passed at `d2cb66e`. PR head `94bacaf` pinned medfit v0.20.0
by release SHA, and both [PR R-CMD-check](https://github.com/Data-Wise/missingmed/actions/runs/45753640534)
and [PR pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45753640597)
passed.
The PR squash-merged into `dev` as `6245b53`. Post-merge
[R-CMD-check](https://github.com/Data-Wise/missingmed/actions/runs/45755396321),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45755396302), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45755396372)
passed. R-CMD-check reported 2,571 passes, two skips, zero failures, and
zero test warnings. Pages deployment was skipped on `dev`.

## C5 diagnostic on main

[PR #133](https://github.com/Data-Wise/missingmed/pull/133) ported the C5 fix
from [PR #130](https://github.com/Data-Wise/missingmed/pull/130) and merged into
`main` as `0dfefce` on 2026-11-26. SEM MBCO fit errors now identify the dataset
and failed null branch. The single-start replay on medfit v0.19.0
(`2c334734`) passed all 24 cases across `mbco_d4()`,
`infer(type = "mbco")`, both ARIV modes, both nulls, and three dataset positions.
The C5 test made 48 assertions, and all 284 ledger assertions passed without
failures, skips, or warnings. `make ci` passed on R 4.6.2 with the existing pins
(medfit 0.20.0 at `4739e8e`, RMediation 1.11.2, S7 1.0.0). R CMD check
reported zero errors, warnings, and notes, with 2,707 test passes and 10 skips.
Lint and the pkgdown reference check passed. Pandoc reported a nonblocking
`--mathml` deprecation during the reference check. PR #133 retained package
version 0.11.1.

The merge commit passed
[R-CMD-check](https://github.com/Data-Wise/missingmed/actions/runs/45884928030),
[lint](https://github.com/Data-Wise/missingmed/actions/runs/45884927853), and
[pkgdown](https://github.com/Data-Wise/missingmed/actions/runs/45884928037).
R-CMD-check reported 2,775 passes, two skips, and zero test failures or warnings.
The [Pages deployment](https://github.com/Data-Wise/missingmed/actions/runs/45885340967)
published `gh-pages` commit `42c4688`. The updated
[live SEM guide](https://data-wise.github.io/missingmed/articles/lavaan-sem.html)
matched the deployed HTML byte for byte.

## Completed follow-ups

- T6 verified medfit 0.14.0 and synchronized NEWS, help, and vignettes.
  Both the package dependency and the SEM provider runtime guard require
  medfit 0.14.0. The separate typed covariance-retention path requires 0.19.0.
  [DESCRIPTION](../DESCRIPTION#L16) · [SEM provider](../R/mbco_sem.R#L207-L209) ·
  [Covariance-retention guard](../R/mbco_sem.R#L322-L326) ·
  [Issue #106](https://github.com/Data-Wise/missingmed/issues/106)
- T7 is closed with RMediation 1.6.1. PR #117 merged to `dev` at `ca4957f`, where R CMD check, lint, and pkgdown passed and Pages deployment was skipped.
- The [ledger regression suite](../tests/testthat/test-mbco-sem-ledger.R) now covers material negative
  LRs in consistent v1 ledgers and paired failures at the stacked `a = 0` null. The replay inputs
  and [original receipts](../tasks/plan.md#pinned-d5-follow-up-checks) are preserved in the local archive.

## CRAN submission hold

As of 2026-11-26, CRAN medfit 0.3.2 is below missingmed's declared minimum
of 0.14.0. CRAN RMediation 1.6.1 satisfies the declared minimum of 1.5.0.
The earlier RMediation 1.7.1 threshold came from R-devel S7 compatibility
work. Current hosted checks use RMediation 1.11.2. Compatibility on a
CRAN-only setup still needs verification once medfit meets the floor.
[medfit on CRAN](https://cran.r-project.org/web/packages/medfit/index.html) ·
[RMediation on CRAN](https://cran.r-project.org/web/packages/RMediation/index.html) ·
[Declared dependencies](../DESCRIPTION#L16-L17)

## Parked

- Post-v0.3.0 review backlog: `docs/specs/PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` (parked section).
- Provider-handoff reconcile and workflow items: `docs/PLAN-research-workflow-enhancements-2026-10-20.md`.
- Improper-null research (literature scan, simulation design): worktree `feature/heywood-null-research`, note `docs/NOTE-heywood-null-literature-and-sim-design-2026-10-26.md` (not on `dev`).

## Constraints

Companion manuscript runs on `medsim`, not missingmed; missingmed is a dependency leaf. PRs are gated locally (`make ci`).
