# PR #102: T5 evidence closure plan

Updated 2026-10-22. Execution checklist: [todo.md](todo.md).

P1 implemented: guard-trigger controls and three isolated in-memory mutations;
834 deterministic assertions pass. Claude gave scoped static P1 approval but
read only spec excerpts, leaving P2's full clause/body review open. Its exact
branch-message suggestion was implemented and tested after review, not re-reviewed.
P2's clause matrix and one bounded Claude review are recorded in the receipt.
Claude returned needs-attention; completeness interpretations, mutation strength
and omitted review material remain open. T5 remains unaccepted, including the
required real-case gate. Targeted follow-up is now authorized: strengthen all
mutation evidence, add missing bypass controls, document/test the returned-
likelihood versus escaping post-fit-error policy, then rerun tests and Claude.
No author ruling is inferred for exclusion versus refusal or the 64-branch limit.
Follow-up implemented locally: 858 deterministic assertions and all 24 mutations
pass the intended-assertion/zero-error gates. Claude rerun needs-attention;
its intermediate encoding-map finding is refuted by the final complete run.
Final warning-policy qualifications were made afterward (not re-reviewed).
Real-case evidence, exclusion/64-limit/post-fit rulings and recorded independent-
review omissions remain open; see the receipt for exact scope and dispositions.

## Contract and current evidence

The approved authority remains
`docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md`; this plan does not amend it.
The verification receipt is
`docs/specs/NOTE-T5-acceptance-verification-2026-10-22.md`.
At `bdd03e8`, 776 deterministic assertions pass, but T5 is unaccepted: the
bounded search found no qualifying stored improper-null input, guard-trigger
coverage is missing, and Claude's broader spec/test-body review is incomplete.
Passing injected diagnostics cannot establish real optimizer warning behavior.

## Author-approved T5 acceptance criteria — 2026-10-22

Approved in chat after the explicit criteria proposal. This operational checklist
clarifies acceptance without editing the approved spec. PASS requires evidence
for every required row; demonstrated incorrect behavior is FAIL; missing or
insufficient evidence is BLOCKED. A passing test count alone is not acceptance.

| Required gate | PASS evidence | FAIL or BLOCKED condition |
|---|---|---|
| Likelihood validity (§3b, §4.7) | Both nulls in every imputation/stack and both ARIV modes validate finite raw LR, documented tolerance/roundoff, matching comparison contracts and positive consistent dimensions; invalid losing branches refuse with dataset/branch; bypasses are detected. | Material negatives accepted/floored, nonfinite summaries pass, or missing tolerance/matching-contract evidence. |
| Branch completeness (§3c, §4.8) | Each listed scenario maps to executable evidence: both partial-failure orderings, potentially better unresolved branch (1 versus survivor 9), optimizer/postfit distinction, success minimum, all-failure, reasoned infeasibility, duplicates, 64-limit, immediate/nested and public propagation. Supported separate nulls fail closed; unsupported generic-product routes refuse before delegation, including aliases/nesting. | Convergence/silence proves completeness, survivor produces valid inference, exclusions depend on error text, or a listed scenario lacks adequate evidence. Refusal is not a claim to implement dependency branch enumeration. |
| Independent df/compatibility (§3d, §4.9–10) | Independent K=20 positive-ARIV Chan–Meng/Li answers, zero/threshold controls, encoding, stack/K, own/fixed, ties, labeled diagnostics, dimensions and numeric indexing pass; planted defects detected; frozen provenance retained. | Expected answers reuse tested helper, only D4/p checked where labels matter, or frozen outputs change. |
| Diagnostic attribution (C5/§3) | Injected a-only/b-only/both identity and once-per-dataset warning aggregation; diagnostic mismatch/error refuses; full fixed-x and separate null factor/fixed-x guards have isolated rejection and matched success controls. | Identity rests solely on warning order/count; mismatched refits accepted; guard bypass survives. |
| Real dependency integration (author-added gate) | At least one qualifying pre-existing stored input/model, without injected diagnostics, reproduces an improper null. Independently inspected full/a/b diagnostics establish identity; fallback samples/settings and both raw LRs match; provider/public attribution is correct; saved artifacts unchanged. | No qualifying/reproducible case, mismatch, or wrong attribution. One case does not establish all asymmetric/both scenarios. This requirement is the author's hold, not an unambiguous original-spec fixture requirement. |
| Reproducible verification | Final deterministic files and relevant mutation controls pass using pinned existing medfit identity; exact counts and zero unexpected failures/errors/warnings/skips recorded; fixture hashes unchanged; mutants fail intended assertions rather than unrelated execution errors. | Stale receipts, unidentified dependency, skipped required case, incidental mutation errors. |
| Complete review evidence | Clause-to-test-body matrix identifies evidence type; Claude reads full relevant clauses, final implementation/tests and harnesses; findings dispositioned and omissions explicit. | Excerpt-only review, unreviewed final edits, or approval label overstating actual inspection. |

Remaining gaps close through: qualifying real stored input (not more injected
tests), complete final clause/body review, and review of P1's final assertion
hardening. No automatic retry or review expansion. New findings remain open
unless evidenced/dispositioned; recording a review is not proof of acceptance.

Optional T5 confidence checks: more stored improper cases, more models/versions,
performance checks and stronger optimizer exploration. Universal global-optimum
proof is not promised. Simulations/calibration remain prohibited. Dependency
floor/NEWS/vignette and full package gates remain T6/T7 obligations, not optional
overall and not silently part of T5. Do not invoke prohibited generators via a
test/check wrapper. No installs, simulations, saved-result changes or merge.

## Options considered (recommended option approved)

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

The author authorized targeted evidence-gap fixes and a fresh bounded review;
no broader branch-enumerator design or spec amendment is inferred. No
dependency installs, simulations, saved-result changes, or merge. Preserve the
unrelated untracked research-workflow plan. Recheck this plan if the approved
spec, medfit version, provider helper, fixture provenance or user constraints
change. Do not repeat broad fixture discovery without a concrete new lead.
