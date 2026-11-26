# missingmed roadmap

Updated 2026-11-25. See the [T5 plan](../tasks/plan.md#current-state-2026-11-24)
for evidence and the [status file](../.STATUS) for the current handoff.

## Shipped

- v0.2.0 S7 rewrite + IPW (2026-06-12); GLM families (PR #5) and `sensitivity_mnar()` (PR #6) (2026-08).
- [v0.11.0](https://github.com/Data-Wise/missingmed/releases/tag/v0.11.0)
  released 2026-11-25 and is available from [Data-Wise R-universe](https://data-wise.r-universe.dev/missingmed).
  It uses medfit for SEM MBCO refits. See [NEWS](../NEWS.md) for release details.

## Website

The [public pkgdown site](https://data-wise.github.io/missingmed/) serves
v0.11.0, including the updated analysis guide and favicon.
[The release deployment](https://github.com/Data-Wise/missingmed/actions/runs/45749138848)
built the site from `bf85884`.

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

## Next

- [PR #120](https://github.com/Data-Wise/missingmed/pull/120) updates the
  contrast-error test for R-devel. The exact PR head passed hosted R-devel checks on
  Linux and Windows. The upstream PR checks stopped at their medfit 0.20.0
  version guard after resolving 0.21.0 from R-universe. The release checks are
  recorded in the [0.11.0 checklist](PLAN-release-0.11.0.md).

- T6 verified the medfit 0.14.0 dependency floor and synchronized NEWS, help, and vignettes. Typed covariance retention requires medfit 0.19.0 or later.
- T7 is closed with RMediation 1.6.1. PR #117 merged to `dev` at `ca4957f`, where R CMD check, lint, and pkgdown passed and Pages deployment was skipped.
- The replay inputs and receipts are in the verified local archive. Porting the two scratch controls into the suite remains a regression follow-up.

## Parked

- Post-v0.3.0 review backlog: `docs/specs/PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` (parked section).
- Provider-handoff reconcile and workflow items: `docs/PLAN-research-workflow-enhancements-2026-10-20.md`.
- Improper-null research (literature scan, simulation design): worktree `feature/heywood-null-research`, note `docs/NOTE-heywood-null-literature-and-sim-design-2026-10-26.md` (not on `dev`).

## Constraints

Companion manuscript runs on `medsim`, not missingmed; missingmed is a dependency leaf. PRs are gated locally (`make ci`).
