# T5: medfit evidence inventory and bounded dependency proposal

2026-10-22. **DESIGN APPROVED; T5 UNACCEPTED.** The author approved the three
recommended T5 rulings (reasoned exclusion, engineering cap, usable-likelihood
preservation) and requested this inventory. Implementation is expressly NOT
authorized by the inventory itself. Subsequently the author approved the design
and separately authorized D1 implementation/tests/Claude review only. D2-D5 remain
unimplemented; current execution and review limits are recorded in tasks/plan.md.
The approved migration spec remains unchanged; no scope waiver.

## Inspected identities and limits

- missingmed baseline `1601b29`, branch `feature/lavaan-mbco-medfit`; approved spec
  SHA256 `b933e60601f4c95dcd763af0c98e0491c20ccac8cef5007451a6a441034469bc`.
- medfit source checkout `dd42073d18bc0463f31a1a0e1d469117689b5b28`, branch
  `feature/factor-gate-registration`, DESCRIPTION 0.10.0. It is another session's
  checkout, inspected read-only; not a proposed implementation base or claim about
  the latest release. Two unrelated untracked medfit plans remain untouched.
- Existing installed medfit 0.11.1:
  `/private/tmp/claude-501/medfit-lib2/medfit`, RemoteSha absent.
  `R/medfit.rdb` SHA256
  `8f0a2c7e6719935753715a59a7dc86e63ef9c00a72cf633e27106e760425c217`;
  `R/medfit.rdx` SHA256
  `801cbbf95c240f996ea9ca696a42575e7ccc3fe68750dc6108200cdb3db93bab`.
  Read-only deparsing confirms raw-grid cap, surviving-minimum behavior,
  covariance-before-return and omitted per-null diagnostics. The installed
  converter additionally retains `optimum`; the older source converter does not.
  Neither field nor version is a completeness/global-optimum certificate.
- Source, test bodies, help comments and installed function bodies were read.
  No fits, test suites, generators, dependency installs or simulations were run.
  Absence assertions below concern the inspected paths, not all medfit versions.

## Remaining evidence gaps

Paths below are relative to `/Users/davood/projects/r-packages/active/medfit`.

| Gap | Concrete inspected evidence | What is still needed |
|---|---|---|
| G1: hidden unresolved subbranch | `R/sem-fit.R:239–272` catches errors as strings, selects the smallest successful `f`, and returns only the winner. Losing warnings/messages are discarded. | A complete branch ledger, structured outcomes and a refusal/incomplete contract when any required branch is unresolved; both partial-failure orderings and public/nested propagation. |
| G2: no reasoned exclusion evidence | The same catch labels any error a failure; it does not distinguish an empty feasible set from an optimizer/post-fit failure. `tests/testthat/test-sem-branches.R:135` covers all-failure, not exclude-and-continue. | A bounded proof-producing infeasibility check and an exclusion-and-continue control. Unknown or numerical near-dependence must remain unresolved. |
| G3: counting/duplicate boundary unproved | `R/sem-fit.R:223–226` expands the Cartesian grid before checking `nrow > 64`; no cross-row deduplication in that path. Existing repeated-factor test at line 46 is not cross-product duplicate-branch evidence. The cap test at lines 142–154 generates random data and checks only overflow; it was NOT run. | Explicit raw/unique counts and duplicate mapping; deterministic below/at/above-cap checks before allocation/optimization. Missingmed syntax refusal is not this test. |
| G4: post-fit payload can escape unreturned | `.sem_fit_syntax()` optimizes at lines 122/126, calls `.sem_vcov()` at 133, then returns at 139. A genuinely escaping error prevents that return. | A structured retained likelihood/optimizer payload and stage-specific post-fit failure; deterministic returned-warning and escaping-error controls through public consumers. No real escaping-error reproduction is claimed. |
| G5: covariance warning is not necessarily an exception | `R/sem-se.R:63–69` deliberately warns and returns an NA matrix when information inversion yields NULL; installed 0.11.1 has the same branch. This already preserves the return path unless a later stage errors. | Preserve this behavior, attach structured covariance status, and distinguish information/identification concerns from a computational covariance exception. No blanket inference permission from finite `f` or NA covariance. |
| G6: ledger/diagnostics vanish at public seams | `R/fit-sem.R:140–143` copies selected fields, not a branch ledger. `R/sem-mbco.R:154–184` aborts on the first failed null refit and returns only constraint/f/diff_ll/converged; no per-null improper/status record. | Versioned public full/a/b records including nested ledgers, notices and stable branch identity; typed failure propagation. This could remove attribution refits later, but does not authorize their removal now. |
| G7: actual dependency integration unproved | Existing missingmed receipt records injected retention, syntax refusal and a bounded search with no qualifying improper-null fixture. | Final version-pinned deterministic integration plus a genuine pre-existing stored improper-null model/input. Neither a new status schema nor the proposal closes that author-added gate. |

Missingmed's current `R/mbco_sem.R:183–203` refuses generic nonlinear/bounded
routes; its two null summaries are validated at lines 439 onward. Retain those
refusals. The dependency proposal does not broaden supported syntax or change
D4, df, ARIV, LR tolerance, warning policy, dimensions or saved reference values.

## Proposed bounded slices (not implementation authorization)

### D1 — Versioned outcome ledger and safe public propagation

Owner: medfit maintainer/Codex, in a separately authorized isolated worktree.
Likely files: `R/sem-fit.R`, `R/fit-sem.R`, `R/sem-mbco.R`, focused tests and help.

Add a documented versioned diagnostics record using existing list extension
points, without changing existing successful numeric columns. Each full/null/
nested branch gets a stable ID, parent ID and exact constraint definition;
separate enumeration state, optimizer/acceptance state, likelihood availability,
feasibility state, covariance state and improper/identification notices. Include
`f`, sample/model/likelihood-domain identity, original condition class/message,
and retained warnings/messages. A Boolean `converged` cannot replace these fields.

Any required unresolved branch makes the union unresolved. Default public
`fit_sem()`/`mbco_sem()` must not return ordinary successful inference from a
survivor. Prefer typed error conditions carrying the versioned ledger and any
best-survivor diagnostic over a new permissive fitting mode; no survivor p-value.
Inspect every bounded required a/b refit even when one fails, then propagate their
outcomes, rather than fabricating an unattempted branch's status. Preserve clean
starts, current solver, all-row acceptance gates and original constraints.

Enumeration complete means all required branches were accounted for, not that
each local solver found a global optimum. Preserve the current optimizer status
separately; no globality flag inferred from agreement or nonnegative LR.

PASS: both partial-failure orderings (including hidden LR 1 versus survivor 9),
all-success minimum, all-failure, missing/malformed ledger refusal, full-fit and
nested input/refit failures pass through public `fit_sem()` and `mbco_sem()`.
Planted survivor-success, status-drop and label-swap defects fail intended
assertions, not incidental execution errors. Stored all-success values unchanged.

### D2 — Narrow, auditable infeasibility certificates

Depends on D1. Owner: medfit maintainer/Codex. Proposed initial proof scope:
literal zero-fixing conflicts with fixed nonzero values or explicit bounds,
and exactly demonstrable affine contradictions. Use a small conservative
dependency-free check; do not introduce a general feasibility solver, infer
infeasibility from near-singular numerical rank, or relabel optimizer exceptions.
Record assumptions, involved constraints, exact contradiction and proof method.
Anything outside the supported proof scope returns unknown, not infeasible.
Initial implementation may be narrower than this proposed scope after design
review, but must identify exactly which certificate types it supports.

Within a generic union, exclude only a certified empty branch in the identical
parameter domain and retain it in the ledger. If no feasible branch remains,
return a typed empty-union failure. An infeasible top-level a=0 or b=0 null must
remain an explicit failure for missingmed's current two-branch/dimension contract;
do not encode it as an arbitrary finite LR or silently infer on the other null.

PASS: an exact contradiction excluded while a resolved sibling determines the
minimum; matched feasible and unknown/near-dependent cases; all-infeasible union;
same model/domain certificate provenance; nested/public propagation. Mutating
unknown/error to infeasible must fail. Whole-model refusal is not the success control.

### D3 — Preserve the 64 raw-combination contract; expose duplicates

Depends on D1. Owner: medfit maintainer/Codex. Compute the Cartesian cardinality
with bounded/overflow-safe arithmetic before constructing the grid. Keep the
existing admission rule: more than 64 RAW combinations refuses, even if many
represent duplicate restriction sets. Do not reinterpret this as 64 unique
branches or raise the limit. Count the factors produced by the existing parser,
not surface-text tokens.

For admitted grids, report raw count, canonical restriction-set IDs, unique
count and mapping of raw rows to those IDs. Keep existing fitting/order/tie
behavior initially; do not add deduplicated execution or prune subsumed branches
in this slice. Structural canonicalization is not a claim of arbitrary affine
equivalence. Over-limit typed conditions report counts and `not_enumerated`,
never a truncated ledger marked complete. Do not allocate an over-cap grid.

PASS: pure cardinality controls below/at/above 64 (including 63/64/65 and overflow),
parsed binary-product grids 32/64/128 with fit calls replaced by deterministic
payloads, overlapping/duplicate product constraints and factor permutations.
Raw-over-limit but unique-under-limit still refuses. Prove optimizer calls are
zero on overflow, and admitted duplicate cases preserve successful minimum and
canonical identities. No synthetic random dataset is necessary.

### D4 — Preserve post-fit evidence without creating false successful fits

Depends on D1. Owner: medfit maintainer/Codex. Snapshot the accepted optimizer/
likelihood context before covariance evaluation. Keep normal successful output
and the existing singular-information warning/NA-covariance behavior. Introduce
a documented typed covariance-stage condition for genuinely escaping covariance
errors, carrying a versioned partial payload and diagnostics; do not catch every
post-fit error as covariance-only. Invalid model/defined-parameter errors and
failed objective/constraint gates remain distinct and unresolved.

`mbco_sem()` may use a retained internal null likelihood only after the ordinary
sample/model/domain, dimension, optimizer/constraint and completeness checks
pass and the failure is exclusively covariance-stage. Preserve its failure notice
and branch identity. An information/identification warning remains a distinct
diagnostic, not automatically cleared by finite `f`. Boundary-validity policy is
not relaxed. No fabricated covariance, standard error, p-value or globality claim.

Public `fit_sem()` keeps throwing on the new escaping-error path but its typed
condition exposes the partial likelihood; it does not return a normal SEMFit
with an invented success state. A full-fit escaping error may therefore still
stop missingmed inference while retaining evidence. Recovery to successful full-
fit inference would require a separately reviewed public input contract for
`mbco_sem()`, not private namespace access or an implicit scope expansion here.

PASS: injected covariance-only throw after an accepted stored-data fit retains
the identical objective and context; existing warning/NA return remains;
optimizer error, nonfinite objective, model/defined-parameter error and
identification concern cannot masquerade as a clean covariance-only success.
Test both null orderings, typed full-fit failure and public payload consumption.
Do not present injected throws as a naturally observed failure or the real-case gate.

### D5 — Consumer integration and final evidence, separately authorized

Depends on D1–D4 and selection of an existing verified dependency build. Owner:
Codex in missingmed; medfit maintainer supplies build/source provenance.
Keep generic-product/bound syntax refusals in place; gaining a ledger does not
approve broader syntax. Add an additive adapter for the documented records and
typed conditions, retaining legacy affine/two-null behavior only where its
existing contract is adequate. Never infer completeness from an absent schema.
Retain validated attribution fallback until replacement has real integration
evidence. Any future dependency floor is chosen by demonstrated capability and
source identity, not today's 0.11.1 version label or source DESCRIPTION alone.

PASS: both public missingmed APIs and ARIV modes validate same sample/settings,
full/a/b outcomes, branch-specific warnings, finite raw LRs and dimensions;
missing/unknown schema and unresolved nested branches refuse. Original frozen
inputs/results are hashed and unchanged. Future deterministic runners must be
allow-listed by test body: existing medfit branch tests include random generation
and cannot be executed wholesale under the current prohibition. No installs are
authorized to obtain a new build; availability is a prerequisite, not permission.

Before acceptance, explicitly authorize a final Claude implementation review of
a frozen code/spec/test/dependency snapshot covering all required bodies and
mutations; resolve findings and required omissions. No automatic review retry.
P3's real stored improper-null case remains independently required. No full
package/random suite, release, merge, external issue write or repository message
is authorized by this inventory.

## Recommended decision and exclusions

Recommend author approval of D1–D4 as a bounded dependency design, followed by a
separate implementation instruction to the medfit owner; authorize D5 only after
the dependency evidence is available. This document itself does not authorize
those actions. Retain T5 UNACCEPTED throughout unmet requirements.

Rejected expansions: replacing the optimizer, general nonlinear feasibility,
global-optimum certification, new survivor-bound inference, deduplication that
changes the 64 admission rule, more supported missingmed syntax, fabricated
fixtures and weaker spec/real-case gates. No external coordination was performed.

Revalidate this inventory if the inspected sources, installed library hashes,
public diagnostics schema, approved spec, or author constraints change.
