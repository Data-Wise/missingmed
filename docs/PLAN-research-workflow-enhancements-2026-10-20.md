# Plan: Provider replacement evidence and pinned dependency handoff

Filed 2026-10-20 after explicit user authorization to file the
research-workflow plans.
Status: proposed follow-up; filing only, not implementation or acceptance
evidence.

> **Note 2026-10-26:** kept as a record. PR #102 (merged to `dev` as `9f77220`) overlaps
> tasks 1-2, but no task here was reconciled or ticked. `tasks/plan.md` is authoritative for
> the current queue; the task 3 cross-repository handoff (D5, blocked on medfit-oct-23) is still open.

**Owner:** missingmed maintainer; medfit and RMediation own their APIs.
**Observed local identity:** `feature/lavaan-mbco-medfit` at `7a6bd547b4e9`.
This is a dated
checkout observation, not a release/installed-package assertion; recheck
before execution.

## Scope and holds

Preserve active provider work and dependency ownership; no scientific method
change here.
Preserve unrelated work, current scientific rules, active plans and
per-instance external-action gates.
No simulation, installation, manuscript revision, submission, release or
deployment ran for this filing.
This dated plan supplements existing plans; it does not replace their queue or
certify completion.

## Ordered tasks

### 1. Reconcile the active provider handoff

- [ ] Read the current .STATUS and existing lavaan-MBCO plan; identify the
      completed parsing work and unresolved parity/planted-defect work before
      adding tasks.
- **Acceptance:** No completed T1 work is repeated; dependency floor, loaded
  library and exact provider ref are recorded separately.
- **Verification:** Inspect existing handoff, DESCRIPTION and source; do not
  install a dependency merely to file this plan.
- **Dependency:** None; reconcile existing evidence first.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

### 2. Specify provider parity controls

- [ ] Define a pinned numerical oracle and planted-defect controls for
      full/a=0/b=0 log-likelihoods, convergence, and supported covariance/mean
      settings.
- **Acceptance:** Preserve the union null and D4 pooling; package routines and
  research-local methods are not declared interchangeable from function names.
- **Verification:** Execute the existing focused tests only during later
  scoped implementation; preserve failure and unsupported-case assertions.
- **Dependency:** Task 1; retain the existing project approval gates.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

### 3. Define the cross-repository handoff

- [ ] Record the evidence expected from medfit/RMediation and acceptance in
      missingmed; list version/API/documentation changes by owner.
- **Acceptance:** No manuscript dependency on missingmed is implied; Missing
  Effect production remains medsim.
- **Verification:** After later changes run owning document/test/check and
  inspect pkgdown; external submission/deployment stays separately gated.
- **Dependency:** Task 2; retain the existing project approval gates.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

## Checkpoint and first action

- [ ] After tasks 1–2, reconcile evidence and unresolved decisions before
      beginning task 3.
- [ ] Record actual verification and remaining owner decisions; do not tick
      future execution from this filing.

**First action:** the named maintainer reads the existing evidence in task 1
and reconciles its
residual scope with the current owning plan. Stop if evidence conflicts or a
scientific/author
decision is unresolved; name that decision rather than silently changing the
plan.

## Coordination

- [Shared Savant enhancement plan][ref1] owns reusable command/skill work.
- [medfit companion plan][ref2] owns its repository changes.
- [RMediation companion plan][ref3] owns its repository changes.
- Future execution must follow this repository's instructions, tests, artifact
  checks and branch model.

[ref1]: </private/tmp/savant-simulation-completeness/tasks/plan-research-workflow-2026-10-20.md>
[ref2]: </Users/davood/projects/r-packages/active/medfit/tasks/PLAN-research-workflow-enhancements-2026-10-20.md>
[ref3]: </Users/davood/projects/r-packages/active/RMediation/tasks/PLAN-research-workflow-enhancements-2026-10-20.md>
