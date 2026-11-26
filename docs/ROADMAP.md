# missingmed roadmap

Updated 2026-11-26. See the [T5 plan](../tasks/plan.md#current-state-2026-11-24)
for evidence and the [status file](../.STATUS) for the current handoff.

## Shipped

- v0.2.0 S7 rewrite + IPW (2026-06-12); GLM families (PR #5) and `sensitivity_mnar()` (PR #6) (2026-08).
- [v0.11.0](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.0)
  released 2026-11-25 and is available from [Data-Wise R-universe](https://data-wise.r-universe.dev/missingmed).
  It uses medfit for SEM MBCO refits. See [NEWS](../NEWS.md) and the
  [release checklist](PLAN-release-0.11.0.md) for release details and checks.

- [v0.11.1](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.1)
  released 2026-11-26 from `main` at `42b4805` ([PR #128](https://github.com/Data-Wise/missingmed/pull/128)).
  It includes the R-devel contrast-error test fix and SEM ledger regression
  controls. See the [release checklist](PLAN-release-0.11.1.md).

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

The [public pkgdown site](https://data-wise.github.io/missingmed/) serves
v0.11.1. The [post-merge pkgdown build](https://github.com/Data-Wise/missingmed/actions/runs/45773976381)
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

## T5 evidence and owner decision

The owner **accepted T5 on 2026-11-25** on missingmed `8dac15d` and medfit
v0.19.0 `2c334734`. The [checklist](../tasks/todo.md) records the evidence and
the [plan](../tasks/plan.md#acceptance-checkpoint-and-downstream-tasks) records
the decision.

| Gate | Owner | State |
|---|---|---|
| P3: improper-null real-case evidence | author | Met 2026-10-26 (ruling B, gate amended): simulated seed 45 qualifies, origin SIMULATED; mechanism check in the worktree note. Collaborator route, R3 and R5 dropped; route plan `docs/PLAN-p3-raw-data-routes-2026-10-24.md` is historical. Limits in `tasks/plan.md` P3 |
| D4 independent closure | Independent reviewer | No separate D4 sign-off recorded. The T5 disposition records targeted review coverage and the comparison of covariance error handling on both medfit versions. |
| D1–D4 integration | medfit | Pinned v0.19.0 (`2c334734`) includes narrowed covariance retention. |
| D5 integration | Codex | Implemented locally at `8dac15d`. Pinned tests cover both APIs, both ARIV modes, and refusal of invalid ledgers. |
| D5 qualifying-case replay | Codex | The five-imputation replay pooled with the recovered single start for imputation 3's `a = 0` null. All 18 same-engine fits agreed on raw LRs. The shipped-default check exercised native retries separately. |
| T5 acceptance | Owner | Accepted 2026-11-25 after the P2 findings disposition and Opus follow-up. |

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

## Next

- T6 verified the medfit 0.14.0 dependency floor and synchronized NEWS, help, and vignettes. Typed covariance retention requires medfit 0.19.0 or later.
- T7 is closed with RMediation 1.6.1. PR #117 merged to `dev` at `ca4957f`, where R CMD check, lint, and pkgdown passed and Pages deployment was skipped.
- The [ledger regression suite](../tests/testthat/test-mbco-sem-ledger.R) now covers material negative
  LRs in consistent v1 ledgers and paired failures at the stacked `a = 0` null. The replay inputs
  and [original receipts](../tasks/plan.md#pinned-d5-follow-up-checks) are preserved in the local archive.

## Parked

- Post-v0.3.0 review backlog: `docs/specs/PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` (parked section).
- Provider-handoff reconcile and workflow items: `docs/PLAN-research-workflow-enhancements-2026-10-20.md`.
- Improper-null research (literature scan, simulation design): worktree `feature/heywood-null-research`, note `docs/NOTE-heywood-null-literature-and-sim-design-2026-10-26.md` (not on `dev`).

## Constraints

Companion manuscript runs on `medsim`, not missingmed; missingmed is a dependency leaf. PRs are gated locally (`make ci`).
