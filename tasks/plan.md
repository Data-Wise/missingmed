# PR #102: T5 evidence closure plan

Updated 2026-10-22. Execution checklist: [todo.md](todo.md).

P1 implemented: guard-trigger controls and three isolated in-memory mutations;
834 deterministic assertions pass. Claude gave scoped static P1 approval but
read only spec excerpts, leaving P2's full clause/body review open. Its exact
branch-message suggestion was implemented and tested after review, not re-reviewed.
T5 remains unaccepted pending real-case evidence and remaining review coverage.

## Contract and current evidence

The approved authority remains
`docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md`; this plan does not amend it.
The verification receipt is
`docs/specs/NOTE-T5-acceptance-verification-2026-10-22.md`.
At `bdd03e8`, 776 deterministic assertions pass, but T5 is unaccepted: the
bounded search found no qualifying stored improper-null input, guard-trigger
coverage is missing, and Claude's broader spec/test-body review is incomplete.
Passing injected diagnostics cannot establish real optimizer warning behavior.

## Options and recommendation

1. **Recommended: close independently actionable gaps first.** Add deterministic
   guard-trigger controls, then commission one explicitly scoped Claude review
   of actual spec and test bodies. Keep the real-case gate open while the author
   identifies an existing stored input. This advances verification without
   weakening acceptance or repeating the same unsuccessful search.
2. **Input-first:** wait for an author-supplied stored case before further work.
   This avoids additional review before integration evidence exists but leaves
   known deterministic coverage gaps idle.
3. **Defer T5/PR:** retain the draft and resume when an admissible input exists.
   Do not substitute generated data, inferred diagnostics, or a spec waiver.

## Ordered work

### P1: Deterministic guard coverage — Codex, small

Add isolated injected controls triggering nonempty fixed-x state and rebuilt
factor/fixed-x state mismatch. Assert inference stops before pooling rather than
misattributing a/b. Include a matched success control. Inspect the helper's
actual branches before deciding the exact cases; remove/bypass each guard in
temporary mutation checks to prove the new tests detect it. Restore mutations.
Expected files: attribution tests and verification receipt; change production
code only if a confirmed defect is separately in implementation scope.

### P2: Complete spec evidence review — Codex + Claude, medium

Rerun the five existing deterministic files using the existing medfit library;
record exact counts, library version, warnings/skips and saved-input hashes.
Create a clause-to-test-body matrix for C5/3, 3a–3d and 4.7–10, distinguishing
injected, real stored, untested, and independently reviewed evidence. Request a
single bounded Claude plugin review that reads these bodies, provider/helper,
mutation harness and relevant public documentation. Record omissions and
findings; no automatic retries or broadened clean verdict. A missing real case
remains an explicit gap even if the rest is approved.

### P3: Real-case attribution gate — author input, then Codex, medium

Author supplies the location and provenance of an already stored input/model
known to yield an improper null. Verify read-only that the fitted full/a/b
diagnostics identify the affected branch and that diagnostic refits match the
provider's LR/settings gates using the existing medfit library. If the candidate
is proper, fails convergence, or cannot reproduce attribution, record it as
nonqualifying; do not retune data or generate a replacement. Exercise provider
and public once-per-dataset warnings, including branch identity. Hash existing
inputs before/after; do not modify saved results. Do not assume this single case
establishes all asymmetric/both-branch scenarios; retain injected controls.

### Acceptance checkpoint and downstream tasks

T5 closes only when the approved requirements have mapped, passing evidence,
the real-case gap is resolved, and Claude findings/coverage omissions are
dispositioned. Then resume T6 dependency-floor/NEWS/vignette work. T7's full
checks require a separate execution-scope check: do not invoke a runner that
executes prohibited simulations or updates saved artifacts. Passing this plan
does not authorize push, merge, install, simulation, or external submission.

## Boundaries and invalidators

Planning only in this session; implementation/review are future steps. No
dependency installs, simulations, saved-result changes, or merge. Preserve the
unrelated untracked research-workflow plan. Recheck this plan if the approved
spec, medfit version, provider helper, fixture provenance or user constraints
change. Do not repeat broad fixture discovery without a concrete new lead.
