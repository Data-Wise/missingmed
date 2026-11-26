# D4 closure matrix — approved clauses and nonwinning-child evidence

## Frozen scope

Review source: medfit `f31e12e` on `codex/medfit-d4-post-fit-evidence`, with only
`tests/testthat/test-sem-post-fit.R` expanded in this follow-up. No production
logic or approved specification changed. Caller source is missingmed `c2af811`.
The dependency worktree is `/private/tmp/medfit-d1.3jrA2K/medfit`; caller paths below
are relative to `/Users/davood/projects/r-packages/active/missingmed`.

Authoritative sources, read directly rather than inferred from earlier reviews:

- `docs/specs/PROPOSAL-T5-medfit-evidence-contract-2026-10-22.md:131–159` (D4).
- `docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md:34` (C5),
  `110–171` (3c/3d), `193–202` (test items 8–10, also called §4.8–§4.10).

## Clause-to-source-to-test mapping

| Requirement | Source inspected | Executable evidence / boundary |
| --- | --- | --- |
| D4: snapshot accepted likelihood before covariance; do not relabel model/definition/optimizer/nonfinite errors | medfit `R/sem-fit.R` `.sem_fit_pipeline`, `R/sem-se.R` `.sem_defined`, `R/sem-outcomes.R` `.sem_outcome`/`.sem_require_outcome` | `test-sem-post-fit.R`: public typed failure, non-covariance failures, nonfinite/unaccepted optimization; identical `f`, theta, post-deletion context and missing vcov/defined asserted. |
| D4: documented versioned public condition, not a successful SEMFit or private full-fit recovery | medfit `R/fit-sem.R` help and `.sem_as_semfit`; `R/sem-outcomes.R` abort/retain/validation helpers; generated `man/fit_sem.Rd` | Full `test-sem-post-fit.R` public-payload and malformed-payload bodies, including formerly unread lines 1–99. `mbco_sem(err)` refuses; normal singular-info warning/NA return remains. |
| D4: internal null-only retention after ordinary context/dimension/optimizer/completeness gates | medfit `R/sem-mbco.R:181–256`, full outcome validators, full `.sem_fit_branches` | Both direct null positions; nested child positions; malformed schema/dimension controls. Existing `test-sem-outcomes.R` acceptance/context/child tampering and unresolved-ordering controls remain in the deterministic runner. |
| D4 + C5: covariance/identification notices remain distinct and attributable; boundary policy unchanged | medfit full capture/condition/replay/rebase helpers, `.sem_fit_syntax`, `.sem_fit_branches`, `mbco_sem`, `.mbco_warn_boundary` | Singular-info and both-null identification tests; nested failure tests. New nonwinning tests assert losing child ID, failure/identification notices, healthy winner covariance/no post_fit, first-failure root post_fit, unchanged winner objective and p. Existing boundary-typed-error body in `test-sem-outcomes.R` remains. Boundary production helper is unchanged. |
| C5 public dataset aggregation | caller `R/mbco_sem.R:417–469`, `R/mbco_mi.R:285–323` | `test-mbco-sem-acceptance.R:116–141`, `292–335`, `423–456`, `467–477` cover returned warnings, branch attribution and one dataset-naming warning; escaping errors refuse. These are regression evidence, NOT integration of D4's new typed records into missingmed. That adapter is D5. |
| 3c + item 8: losing branch must not disappear; accepted likelihood distinct from covariance success | medfit complete outcome tree validation and branch enumerator, public conversion, null loop | Full D4 bodies plus existing `test-sem-outcomes.R` public/direct/nested/all-failure/survivor controls. New tests choose a strictly worse branch on stored inputs, reverse product order, and target each null separately. No unknown branch is excluded; no optimizer/completeness gate relaxed. |
| 3c required exclusion, duplicate and 64-raw controls | unchanged D2/D3 code and prior review receipts | Existing deterministic files `test-sem-literal-certificates.R`, `test-sem-branch-map.R`, `test-sem-outcomes.R` rerun. This follow-up does not redesign exclusions, deduplicate execution or change the cap. |
| 3d + item 9: historical df/provenance unchanged | caller `.mm_d4_from_stats` remains unchanged | `test-mbco-sem-acceptance.R:17–43`: independent K=20/k=1 Chan–Meng/Li contrast, zero ARIV and both threshold sides; existing fixture provenance test rerun. No df API or saved-output change. |
| 3d + item 10: encoding, scaling, labels, own/fixed modes, ties, diagnostics and dimensions unchanged | caller `R/mbco_mi.R` pooling/df helpers; medfit `R/sem-mbco.R:242–256` LR/p consumption unchanged | Full `test-mbco-encoding.R`: separate injected oracles and mutants, K=3 positive own ARIV, k=2 factors, paired labels, ties, stack/imputation mismatch, own/fixed scaling. Full provider/acceptance files rerun. New D4 internal tests also compare `tests`, statistic and p exactly against clean stored-data baselines. |
| D4 real-case and T5 acceptance boundary | approved proposal D4 PASS and D5 | Covariance exceptions here are injected after deterministic stored-input optimization. They are not naturally observed improper-null evidence. D5 and qualifying real-case evidence remain open; T5 UNACCEPTED. |

## Nonwinning-child finding disposition

The documented conservative root behavior is retained: root `post_fit` comes
from the first covariance-failing child, while root likelihood comes from the
minimum-discrepancy child. No change to winning-branch choice or covariance policy
is justified by the earlier low finding. The new public control reverses product
order so that the strictly nonwinning child is exercised in both positions. The
internal control also targets both nulls and checks rebased child IDs, notices,
healthy sibling state, other-null state and unchanged full-fit subtree.

Two scratch in-memory mutations were tested without changing source or fixtures:
wrong root condition attribution causes eight intended assertion failures;
dropping failed-child notices causes twelve intended assertion failures. Both
new test bodies fail under each mutation, with no runtime/test errors. The first
scratch harness attempt lacked reporter file initialization and stopped before
evaluating tests; adding the same start/end-file calls as the existing runner
fixed the harness. This is not a production bug or RED reproduction.

## Verification and independent review

Dependency allowlisted runner: 768 assertions (45 legacy stored controls +104
expression +160 outcome +85 literal certificate +176 branch map +198 post-fit).
Consumer runner: 816 (95 encoding +126 provider +595 acceptance). Total: 1584.
No failures/errors/unexpected warnings. Final test-file lint is checked after the
counter-state cleanup. Stored fixture blob remains
`13b372d9fcf182dbbeae5b426621cedc2a9dd276`. No full stochastic suite/R CMD check,
installs, simulations, saved-result changes, push or merge.

Focused Claude job `5ad08ae8-f2de-48d9-8c29-d54a6f621c52` failed with
`error_max_structured_output_retries`; no valid structured verdict. Requested
Sonnet, effective `claude-sonnet-5-5`, medium effort; 19 turns, 641819 total
tokens (20 input +63299 cache creation +557035 cache read +21465 output),
$0.5235895, 177013ms runtime/157277ms API. Neither cost/turn limits nor the
Evidence Lease was exhausted. Session/resume hint and all failure metadata are
preserved in `D4-closure-claude-review-2026-10-22.json`; no retry/resume performed.

Read operations confirm the full post-fit test file, outcome helpers, covariance
helpers, branch-enumerator body, null-loop/LR consumption, caller provider/pooling,
proposal excerpt and original 3c/3d/items8–10 were accessed; C5 was retrieved by
grep. They do not establish a successful final coverage review. Required unread
material includes full fit wrapper/pipeline beyond diff hunks, full MBCO entry/
boundary helpers, generated fit_sem help and CLAUDE guidance, caller df helper,
encoding/acceptance test bodies and dependency outcome test bodies. Exact read
operations, failed finalization attempts and terminal CLI result are in the receipt.

Truncated, unvalidated draft text raises three concerns: blanket covariance-stage
classification, first-failing-child coverage with two failures/exact notice text,
and missing root-post_fit-to-child validation. No valid review verdict or complete
recommendation/coverage object was produced. These concerns remain open rather
than being silently discarded or treated as independently confirmed blockers.
Owner inspection finds acceptance/definition validation before the narrow
`.sem_vcov` catch, not a catch around all post-fit work; information/active-set/
score helpers inspected do covariance calculations, not a fresh optimizer
acceptance gate. That does not settle every possible classification concern.
Two-failure/exact-notice and root-validator hardening remain unimplemented.

The requested nonwinning-child controls and owner clause tracing are complete;
independent D4 closure is NOT complete. Next bounded action requires author
authorization for a fresh focused review of the unread bodies and draft concerns.
D5 and qualifying real-case evidence remain open; T5 UNACCEPTED.
