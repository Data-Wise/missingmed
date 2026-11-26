# SPEC: review/handoff protocol (harness-review follow-up)

Status: DRAFT, deferred. Source: `/agentic-harness:harness-review` on 2026-10-26 (no harness exists; both findings low priority).

## Problem

Recurring review and handoff work (D4 review subagent, Codex handoffs, medfit evidence PRs) lives as prose in `tasks/plan.md`. Each repeat re-derives the same steps.

## Scope

One optional skill, `.claude/skills/review-handoff/SKILL.md`, covering only steps already practiced this stretch:

1. State the gate being closed and its owner (from `tasks/plan.md`).
2. Cross-repo writes: ask per instance; record the branch and PR.
3. Evidence block for the PR body: exact command, pass/fail/skip counts, baseline run on the base branch, failing-test mapping.
4. Framing rule: label each addition as a tightening or a gap-closer only after a mutation run supports it.
5. Record outcome once: `tasks/todo.md` line plus `.STATUS`; no restating elsewhere.

Out of scope: an orchestrator, agents, tracker sync, and any change to `CLAUDE.md` beyond a one-line pointer.

## Trigger to build

Build only if D5 integration or the next independent review repeats steps 1-5 by hand. Until then the prose in `tasks/plan.md` stands.

## Acceptance

- A fresh-context agent given the skill and a PR task produces a body with items 1, 3 and 4 filled and no unrequested cross-repo write.
- A planted unsupported "closes a gap" claim is caught.
- `make ci` unaffected (docs/skill only).

## Open question

Ownership of the evidence-block template: missingmed or the mediation-planning hub (medfit PRs use it too)? Recommendation: hub, since medfit and missingmed both consume it.
