# missingmed roadmap

Updated 2026-10-26. Index only: each item points to the file that owns its detail, so nothing here restates it.
Authoritative current state: `tasks/plan.md` ("Current state") and `.STATUS`.

## Shipped

- v0.2.0 S7 rewrite + IPW (2026-06-12); GLM families (PR #5) and `sensitivity_mnar()` (PR #6) (2026-08).
- v0.10.0 released 2026-10-14 (GitHub, r-universe); `dev` is 0.10.0.9000. Per-release detail: `NEWS.md`.
- PR #102 (lavaan MBCO on medfit) merged to `dev` 2026-10-26 as `9f77220`.

## Now: close T5 (follow-up gates on `dev`, not PR blockers)

T5 is UNACCEPTED until the real-case evidence gate closes. Checklist: `tasks/todo.md`; rationale: `tasks/plan.md`.

| Gate | Owner | State |
|---|---|---|
| P3: improper-null real-case evidence | author | Met 2026-10-26 (ruling B, gate amended): simulated seed 45 qualifies, origin SIMULATED; mechanism check in the worktree note. Collaborator route, R3 and R5 dropped; route plan `docs/PLAN-p3-raw-data-routes-2026-10-24.md` is historical. Limits in `tasks/plan.md` P3 |
| D4 independent closure | Claude review | Open; no automatic retry |
| D1-D4 integrated into a medfit missingmed can depend on | medfit-oct-23 | Met 2026-10-26: in medfit 0.15.0 (re-landed, PRs #336-#342); equivalence to reviewed receipts unverified |
| D5 integration + qualifying real case | Codex | Unblocked by the row above; not started |

## Next: after T5 acceptance

- T6: dependency floor, NEWS, vignette work (`tasks/plan.md`, "Acceptance checkpoint").
- T7: full checks, after a separate execution-scope check.

## Parked

- Post-v0.3.0 review backlog: `docs/specs/PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` (parked section).
- Provider-handoff reconcile and workflow items: `docs/PLAN-research-workflow-enhancements-2026-10-20.md`.
- Improper-null research (literature scan, simulation design): worktree `feature/heywood-null-research`, note `docs/NOTE-heywood-null-literature-and-sim-design-2026-10-26.md` (not on `dev`).

## Constraints

Companion manuscript runs on `medsim`, not missingmed; missingmed is a dependency leaf. PRs are gated locally (`make ci`).
