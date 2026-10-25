# PR #102: T5 evidence closure plan

Updated 2026-10-24. Execution checklist: [todo.md](todo.md).

## Current state (2026-10-24) — read this first

- **Status:** T5 UNACCEPTED and BLOCKED. P3 (a stored improper-null input with provenance) is the open gate; the
  author ruled medfit's seeded `sem_model_heywood()` nonqualifying (see P3). D4 is not independently closed;
  D5 is not started.
- **PR #102:** draft, base `dev`, pushed through `a20160c`. Not merged.
- **Authorization since 2026-10-22:** the author approved pushing this branch (three pushes on 2026-10-24) and
  approved returning #102 to draft. Merge, simulations and saved-result changes remain unauthorized. Scratch-library
  `R CMD INSTALL` of medfit (dev, the D4 head) was done outside the user library on 2026-10-24 to prove the 0.14.0
  warning; disclosed here and in `.STATUS`. Older "no installs/push" sentences below are dated history.
- **Current baseline:** 816 consumer expectations (95 encoding + 126 provider + 595 acceptance) re-verified
  2026-10-24 on the D4 head `3a98bf6` (medfit 0.12.0), identical before and after the `meanstructure` edit. The 768
  dependency-side count (1,584 total) comes from the D4 closure matrix and was not re-run. Counts 776/858/1055/1300/
  1386/1470 below are historical stages.
- **Decisions (author, 2026-10-24):**
  1. **Path A chosen** (confirmed in chat; it was the 2026-10-22 approval of the bounded D1–D5 dependency design): the
     approved spec stays unamended and every requirement still needs evidence. Path B is not in play.
  2. **Late edits are in the frozen review snapshot:** `e9e2325` (`meanstructure = NULL`) and `2baa3e6` (guard test)
     must be named by SHA in the final review; the acceptance row treats unreviewed final edits as BLOCKED.
  3. **D1–D4 integration into medfit is owned by the medfit session (`medfit-oct-23`), after 0.14.0 ships.** The D-chain
     touches 7 `R/` files; 6 of them (`classes.R`, `fit-sem.R`, `sem-fit.R`, `sem-mbco.R`, `sem-se.R`,
     `sem-syntax-help.R`) also changed on medfit `dev` since the 0.12.0 base `505e8ed`, so expect real rebase work.
     D5 cannot start until D1–D4 exist in a medfit missingmed can depend on. The commits are protected only by local
     branches `keep/d4-3a98bf6` and `keep/d3-pin-cba4c1a`, not pushed.
- **D1–D5 (medfit work for T5; details in the PROPOSAL doc linked below):** D1 outcome ledger and public propagation;
  D2 literal-equality contradiction certificates; D3 overflow-safe 64-RAW cap and duplicate branch maps; D4 post-fit
  covariance-stage evidence retention; D5 integration into the missingmed adapter using documented evidence, not
  private namespace recovery (not started).
- **Receipt availability (checked 2026-10-24):** the `/private/tmp` worktree and library paths below no longer exist.
  The D1–D4 receipt notes are committed in medfit at `keep/d4-3a98bf6:planning/specs/NOTE-D{1,2,3,4}-*.md`
  (recoverable). Truly gone: the D1 assertion-tolerance review JSON and the installed medfit 0.11.1 library; claims
  resting only on those are unauditable (see the `[MISSING]` marks). Other review JSONs are in `docs/specs/`.

## Current checkpoint — D4 post-fit evidence and wrap-up

Latest follow-up: [closure matrix](../docs/specs/D4-closure-matrix-2026-10-22.md).
Nonwinning-child controls now explicitly cover both product orders and both nulls,
healthy winner/other-null state, exact child IDs, retained identification/failure
notices and unchanged LR/statistic/p. 1584 deterministic assertions pass; new test
lint clean; attribution/notice mutations fail the intended assertions. No production
logic changed. Claude5ad08ae8 failed structured-output finalization; no valid verdict,
required unread bodies and three unvalidated draft concerns remain. **D4 is not
independently closed; T5 remains UNACCEPTED.** Author requested wrap-up; next action
is author authorization for a fresh focused review, not D5 implementation. Historical
counts and open-gap descriptions below are superseded by this follow-up.

**Late edit 2026-10-24, value-neutral, NOT Claude-reviewed:** `R/mbco_sem.R:222` and
`test-mbco-sem-acceptance.R:360` now pass `meanstructure = NULL` (medfit 0.14.0
default-change warning; plan in [plan-medfit-defaults.md](plan-medfit-defaults.md)),
plus a guard test in `test-mbco-sem-args.R` (walks installed function bodies, no skip under
R CMD check). On the D4 head `3a98bf6` (kept by local branch `keep/d4-3a98bf6`; `cba4c1a` is
only its D3 base, kept by `keep/d3-pin-cba4c1a`) the receipt's consumer files give 816
expectations before and after, 0 failed.
Part of the frozen T5 review snapshot (author ruling 2026-10-24); value-neutral, but it must be reviewed.

D4 is implemented/tested locally in medfit on commit `3a98bf6` (kept by local branch
`keep/d4-3a98bf6`; the original `codex/medfit-d4-post-fit-evidence` branch does not exist
in the clone) from pinned D3 `cba4c1a`, not integrated. See
[D4 receipt](../docs/specs/NOTE-D4-post-fit-evidence-2026-10-22.md) for the contract,
clause-to-test tracing, exact checks and review limits; `.STATUS` owns current state.
654 dependency +816 consumer =1470 deterministic assertions pass. Claude approves
the scoped code review with one low union-attribution concern, but omitted original
spec clauses and new test lines 1–99/full helper bodies. Post-review wording/harness
formatting is not independently reviewed. D4 is **not independently closed**.

Next bounded step: review omitted clauses/test bodies and close union-attribution
evidence, then separately authorize D5. **T5 remains UNACCEPTED** pending D5 and
qualifying real-case evidence. No simulations/saved-result changes/merge (push and the scratch installs: see Current state).
User requested wrap-up: planning/status/agent docs, website source and memory sync.

Prior D3 omissions were closed by Clauded7e0983c: original clauses/proposal and
conversion/rebase/full tests read; scoped approval, no findings. Raw receipt
`docs/specs/D3-spec-conversion-claude-review-2026-10-22.json`. The descriptions below
are historical; they do not supersede this checkpoint.

## Historical D3 duplicate maps and raw cap

Latest public/format follow-up `cba4c1a` on `08e2dc2`: real stored-data `fit_sem` exact map
oracle, full/both-null nested maps and child IDs/minima, public per-field/child
tamper refusal, and injected nested-null map refusal with rejected evidence.
Count refusal text is non-scientific, approximate above 2^53, explicit overflow;
numeric metadata and the 64-RAW gate are unchanged. 570 dependency +816 consumer
=1386 deterministic assertions pass, zero warnings/errors, changed-file lint
clean; fixture unchanged. No installs/simulations/saved-result changes/push/merge.

Claude0a653f34 approves, no confirmed bugs; optional exhaustive nested tamper and
2^53/non-power count-format cases deferred. Seeding recommendation not adopted:
the public test already uses known-convergent stored inputs and deterministic
single starts/random-retry trap. Review read changed diffs/validator/MBCO but
omitted spec/proposal, full test beyond diff, `.sem_as_semfit` and rebase bodies.
Latest spec closure is therefore incomplete despite scoped code approval;
prior b6e11cec approved base D3 after reading C5/3c/3d/items8-10. Raw latest review
docs/specs/D3-public-format-claude-review-2026-10-22.json; prior closure
docs/specs/D3-closure-claude-review-2026-10-22.json. No automatic repeat.
T5 remains UNACCEPTED; D4/D5 and real-case evidence remain open. Earlier counts
and outstanding-review descriptions below are historical snapshots.

D3 is implemented locally on D2 `a11c63b` in isolated medfit branch
`codex/medfit-d3-branch-map`, local commit `08e2dc2`. Parser-factor cardinality is overflow checked before
grid allocation; admission remains at most 64 RAW combinations. Admitted ledger
nodes expose raw/factor counts, structural restriction-set IDs, unique count and
raw mapping without deduplicating execution, reordering fits or pruning subsets.
Over-cap/overflow errors retain counts and `not_enumerated`, no partial grid.

484 dependency +816 consumer =1300 deterministic assertions pass, zero warnings
or errors; changed code/tests and consumer tests lint clean. Stored fixture hash
unchanged. Source-loaded existing dependencies; no installs or simulations.
Claude b0735071 returned needs-attention, no ship-blocking code defect. Four
concerns addressed/retested: factor/raw-row permutations and per-field tamper,
multi-factor/finite-large counts and exact refusal metadata, non-first duplicate
ties/full forwarding, and a confirmed error-ledger regression from map parsing.
The latter failed before repair; unavailable map now retains its own condition
without replacing the original typed fitting error. Post-review fixes have NOT
been independently re-reviewed; no automatic retry.
Claude read D3/full initial new tests/changed source/docs/parser helpers, but
omitted original C5/3c/3d/items8-10, full existing tests, fixture and mbco_sem.
Codex reread these original clauses: guarded error/notice compatibility (C5),
raw duplicate/cap controls and existing public/nested outcomes (3c/item8), and
unchanged 3d/items9-10 with 816 consumer regressions. Owner tracing is not Claude
closure or D4/D5 acceptance. Receipt in dependency
`planning/specs/NOTE-D3-branch-map-2026-10-22.md`; raw complete review retained at
`docs/specs/D3-claude-review-2026-10-22.json` (Sonnet5.5, medium, 8 turns,
263112 tokens, $0.2535686). Next bounded step: focused Claude closure of the
post-review fixes and omitted original clauses, before dependency integration.
T5 remains UNACCEPTED; D4/D5 and real-case evidence remain open. No saved-result
changes, push or merge. Earlier D2 review notes below are historical.

## Previous authorization — D2 literal certificates on pinned D1

Latest explicit null-attribution follow-up (local medfit `a11c63b`): 85 D2/394 dependency +816 consumer
=1210 deterministic assertions pass, zero warnings/errors; changed test/consumer
lint clean. Tests now pin mbco/null:1 as an all-empty union, each excluded child's
proof/id/parent, and successful nested-null rebasing. Wrong-node, missing-proof
and dropped-child in-memory controls fail intended assertions. No production change.
Claude424e4da7 approves with no findings; actually read C5/3c/3d/items8-10 and
approved D2 PASS clauses. Prior "vacuous" claim rejected independently: full
fit's resolved sibling prevents all-children-excluded predicate. Generated help
read; prior review files/NOTE, roxygen/vignette, full D1 tests and D4 consumer
code omitted. Scoped static D2 approval, not full consumer/D4 verification.
Raw review: docs/specs/D2-null-attribution-claude-review-2026-10-22.json.
Optional additional source-level mutation deferred. T5 UNACCEPTED;
D3-D5 and real-case evidence remain open. The earlier review states below
are historical; no automatic retry, installs, simulations, saved-result changes,
push or merge.

D2 implemented locally in `/private/tmp/medfit-d1.3jrA2K/medfit` [MISSING 2026-10-24], branch
`codex/medfit-d2-literal-certificates`, local commit `d9ace70`, pinned D1 base
`8d7d6c14e038b8f41d9e1bbe37a4e74bf54b404f`. Proof scope is explicit literal
zero/nonzero equalities only; fixed table values, bounds and affine inference
are not proof premises. Resolved siblings may determine a union minimum only
when every other branch resolves or has a reconstructed exact certificate.
All-empty unions and infeasible top-level nulls remain explicit failures.
369 dependency +816 consumer assertions pass (1185 total), no warnings/errors;
source-loaded dependency, no installation. One Claude review returned
needs-attention: consistent fixed-table forgery/unreachable premise, weak null
assertions and empty-min warning addressed and retested. Post-review fixes not
independently re-reviewed; Claude omitted cross-root approved spec/proposal.
Receipt: `/private/tmp/medfit-d1.3jrA2K/medfit/planning/specs/NOTE-D2-literal-certificates-2026-10-22.md` [worktree path gone 2026-10-24; committed copy: medfit `keep/d4-3a98bf6:planning/specs/NOTE-D2-literal-certificates-2026-10-22.md`].
T5 UNACCEPTED. D3-D5 and real-case evidence remain open; no missingmed runtime
integration, installs, simulations, saved-result changes, push or merge.
Earlier authorization/status paragraphs below are historical snapshots.

Item10 optional closure: author-authorized k>1, fixed-mode mutations and shared
state isolation completed, tests only. Winning k=2 dimension oracle and six targeted
mutation types added; 816 consumer assertions/lint pass. Claude64bcc7d9 approves
with no findings, scoped static item10 review. Detailed execution/omissions in
docs/specs/NOTE-ITEM10-hardening-2026-10-22.md. T5 UNACCEPTED; real-case/D5 open.

Item 10 hardening follow-up: three confirmed coverage gaps repaired, no
production changes. Injected tests moved outside the SEM medfit-specific skip;
K=3 positive ARIV, stack-only k mismatch, losing-k and paired swaps added.
776 consumer assertions pass; three files lint clean. Claude03f86a8b approves
exact item-10 mapping; optional k>1, fixed mutants and legacy shared-state
cleanup were nonblocking and are now closed above. Review's swapped-k description corrected in
docs/specs/NOTE-ITEM10-hardening-2026-10-22.md. T5 UNACCEPTED; real-case/D5 open.

Assertion/tolerance follow-up: 1055 deterministic assertions pass (160 D1,
45 stored branches/MBCO,104 expressions,126 provider,620 acceptance). Confirmed
absent-header false positive repaired with zero/one/two-match controls; fixture
loops guarded and Chan-Meng df independently derived. Existing medfit passes
<1e-8 branch-oracle/null-b checks, giving tenfold empirical margin below the
unchanged 1e-7 raw-LR policy, not a universal error bound. Claude78641aac approves
consumer changes but skips cross-root D1 and spec/proposal clauses. Two low
concerns dispositioned: platform drift triggers remeasurement, and null case is
now explicitly tagged (post-review edit retested, not independently re-reviewed).
Class-only refusals/suppressed notices retain their narrower purpose; D5 adapter
and real-case evidence remain open. No automatic review retry. T5 UNACCEPTED.
Receipt: `/private/tmp/medfit-d1.3jrA2K/D1-assertion-tolerance-review-2026-10-22.json` [MISSING 2026-10-24, not recoverable].

Prior D1 follow-up: 329 deterministic assertions passed (306 medfit + 23 consumer).
Exactly-64 raw-branch admission and duplicate/arbitrary positional-ID rejection
now have explicit controls, including an ID-validator mutation check; no fitter
defect or production change was needed. The reported generic-union bypass is not
reachable through the admitted affine-only SEM route. Version-floor/ledger
integration remains D5; the reproduced internal pooling trust seam is outside D1,
and public SEM negative-LR guards pass. Claude job
21ecbeba-ec93-4623-8473-cab0347c5f77 approves with no findings, but omitted the
consumer pooling/provider bodies and proposal in this run; those dispositions
are Codex-verified, not independent full-spec sign-off. D3 does not authorize
deduplicated execution. D2-D5 and real-case evidence remain open; T5 UNACCEPTED.
Full receipt: `/private/tmp/medfit-d1.3jrA2K/medfit/planning/specs/NOTE-D1-outcome-ledger-2026-10-22.md` [worktree path gone 2026-10-24; committed copy: medfit `keep/d4-3a98bf6:planning/specs/NOTE-D1-outcome-ledger-2026-10-22.md`].

2026-10-22: the author approved the three recommended rulings below. They now
govern the evidence review; the approved spec is unchanged and no requirement
has been waived. The author subsequently approved the dependency design and
authorized D1 medfit outcome-ledger/public-propagation implementation, deterministic
tests and Claude review. D2-D5 implementation, installs, simulations, saved-result
changes and merge remain unauthorized. T5 remains UNACCEPTED.

Inventory and bounded D1–D5 changes:
[medfit evidence-contract proposal](../docs/specs/PROPOSAL-T5-medfit-evidence-contract-2026-10-22.md).
Codex has completed the inventory, including source/installed version comparison.
D1 is implemented in `/private/tmp/medfit-d1.3jrA2K/medfit`, isolated branch
`codex/medfit-d1-outcome-ledger` from local medfit origin/dev `505e8ed` (0.12.0).
Scoped local medfit commits: initial D1 `06b2ca9`, post-review follow-up `9abca87`
(fixes after the review, not independently re-reviewed); neither pushed nor merged.
273 deterministic assertions now pass after the authorized focused review and
follow-up; original stored values are unchanged. Focused Claude standard review
of `06b2ca9` read all 11 D1 test bodies and prior post-review fixes: no D1 blocker,
but PROPOSAL-T5 and direct C5/3, 4.8/4.10 reading were omitted (3d coverage
inconsistent, not credited). Three low findings dispositioned: document notices
on attributed children rather than aggregate root; test MBCO error summaries;
defer unmeasured sample-storage redesign, but fix confirmed parent/child objective
inconsistency. Both malformed-objective controls failed before the fix; final
124 focused + 45 selected existing + 104 expression assertions pass. Final
follow-up changes are tested, NOT Claude-reviewed; independent coverage remains
open. No automatic retry. Review job `6b6a1736-0258-4d21-8f85-6cd23b8644cd`,
sonnet / claude-sonnet-5-5, 224145 tokens, 8 turns, 72481 ms, $0.2615716;
no lease/cost/turn exhaustion. Full dispositions/coverage/usage in receipt below.
Receipt: `/private/tmp/medfit-d1.3jrA2K/medfit/planning/specs/NOTE-D1-outcome-ledger-2026-10-22.md` [worktree path gone 2026-10-24; committed copy as above].
Scope deviation disclosed: a restricted R CMD check created its usual temporary
medfit installation inside the isolated check folder. No dependencies or existing
libraries changed; do not repeat under no-installs. Check had one pre-existing
undeclared rlang warning, not a clean pass. P3 and T5 final review remain open.

## Prior proposal revision — research evidence, 2026-10-22

**T5 remains UNACCEPTED. This pass authorizes documentation and one Claude
plan review only.** No implementation, test execution, installs, simulations,
saved-result changes, merge, or amendment of the approved spec is authorized.
Earlier implementation/check counts below are historical receipts, not reruns.
This subsection records the pre-approval scope; the current authorization above
supersedes it. The three rulings were subsequently approved, not implemented.

Historical baseline (superseded by "Current state"): missingmed HEAD `1601b29`; latest recorded verification was
858 assertions and 24 intended-assertion mutations (see the T5 receipt), NOT
rerun in this documentation pass. Counts 776/834 below identify older stages.
All historical authorization statements below are superseded for present action
by the current D1-only scope above. No previously approved option approves these
new three proposed rulings at that earlier checkpoint.

### Proposed rulings and exact closure evidence

| Gap | Recommended ruling (author approved subsequently) | Evidence that closes the existing requirement |
|---|---|---|
| Proved-infeasible exclusion | Preserve the distinction between a mathematically infeasible branch and an unresolved optimizer. Exclude only with a reasoned feasibility determination for the same model/domain; an error message is never that determination. Whole-analysis refusal is safe but does not demonstrate successful exclusion and continuation. | A deterministic, reasoned infeasibility control and matched feasible/unresolved controls, including public/nested propagation. If the supported route cannot exercise exclusion, retain BLOCKED status; a narrower acceptance scope needs an explicit author-approved spec amendment, not a plan interpretation. Never claim exclusion is implemented from pre-fit whole-model refusal. |
| Duplicates and 64-branch limit | Treat 64 as a dependency resource limit, not a statistical guarantee. Keep ordinary a=0/b=0 null comparisons, generic product-zero branch enumeration, and general chart singular strata distinct. Unsupported generic unions must refuse before delegation; this establishes safety, not branch enumeration coverage. | State what the dependency counts (raw combinations versus unique branches), the order of deduplication/capping, and exact below/at/above-limit and duplicate controls where supported. A fixture merely refused by syntax does not exercise the cap. Otherwise leave these controls BLOCKED pending a structured dependency ledger or explicit author-approved scope amendment. Do not silently replace the spec's limit with a different unique-branch algorithm. |
| Post-fit likelihood preservation | Preserve an actually available usable likelihood when only covariance diagnostics fail, while retaining the diagnostic failure and applying the other LR/completeness gates. Separate objective validity, optimization resolution, identification/properness diagnostics, and covariance calculation. A finite objective alone is not acceptance; a covariance error alone is not optimization failure. | Paired deterministic controls distinguish a returned usable likelihood plus covariance-only failure from unresolved optimization, and trace status/likelihood through provider and public consumption. If medfit throws after optimization but before exposing the fit, refuse inference and record a dependency-recovery gap; refusal is not preservation. Close that gap through an authorized structured dependency return and integration proof, or an explicit author-approved scope amendment. No waiver is inferred here. |

These are separate from P3's real improper-null case. Neither more injected
controls nor a favorable plan review closes that real dependency-integration
gate. No branch-enumerator/dependency change is authorized by this proposal.

### Research evidence and limits

Checked local sources in the preceding read-only investigation (2026-10-22):

- **Primary result:** Berger (1997), *Likelihood ratio tests and intersection-union
  tests*, pp. 227–229, Eq. 15.3 and Theorem 15.2.1, local
  `/Users/davood/projects/research/mbco-lrt/pdfs/Berger1997likelihood.pdf`.
  For a finite union, lambda=max(lambda_j), hence -2 log(lambda)=min_j LR_j,
  with a common unrestricted likelihood. LRT/IUT equivalence also requires the
  theorem's equal-critical-value and Theorem 15.1.2 conditions. This supports
  complete union comparison, not dropping failed branches or MI calibration.
  Correction: the PDF exists; the literature note's "none staged" provenance
  is stale. The primary pp. 227–229 were read, not merely that note.
- **Primary hypotheses:** Drton (2009), local `mbco-lrt/text/Drton2009likelihood.txt`,
  lines 195–250, Lemma 2.4 and Theorem 2.6: tangent cones of finite unions unite;
  the LR limit requires a regular ambient model, Fisher information,
  Chernoff-regularity and consistent restricted MLE. This is not a blanket
  chi-square or global-optimizer guarantee for arbitrary SEM/MI fits.
- **Local analytical review, not a paper:**
  `/Users/davood/projects/research/mbco-lrt/docs/planning/codex-review-solver-grill-2026-10-19/review.md`,
  lines 17–38. With deviance LR=F_R*-F_U*, a feasible restricted survivor gives
  an upper bound only with the true unrestricted optimum (or an adequate
  denominator bound) on the same domain. Subtracting a local F_Uhat can destroy
  the bound. Do not substitute survivor p-values/bounds into D4 pooling.
  The same review calls 64 an engineering cap and distinguishes product branches
  from general chart strata; it is not evidence of a literature-mandated cap.
- **Existing numerical evidence, no new run:**
  `/Users/davood/projects/research/mbco-lrt/docs/strategy/ideation-checks/solver-benchmark/a1_R.csv:6644`
  has E6/22/T LR=646.883893530257, reference=646.19263510646, wrong=TRUE.
  `RESULTS.md` lines 30–57 limits these results to inspected observed models
  and records provenance gaps. Local convergence/feasibility does not certify
  objective accuracy; these benchmarks do not validate this provider or latent SEM.
- **MI proof boundary:**
  `/Users/davood/projects/research/Missing Effect/docs/PROOF-TUTORIAL-MBCO-MI.qmd:2623`
  explicitly labels the interior F-law an incomplete proof roadmap and origin
  conservativeness a conjecture checked in prior simulations. WP6's
  `01-lr-inference/sims/m5/README.md` and `REVIEW.md` likewise disclaim general
  SEM certification. Deterministic acceptance verifies the software contract,
  not new calibration, global optimality or a completed MI theorem.
- **Dependency recovery boundary:** inspected current source
  `/Users/davood/projects/r-packages/active/medfit/R/sem-fit.R:133`
  computes covariance before returning the fit. An escaping covariance error
  can hide the earlier optimizer payload. This source observation is distinct
  from the existing installed 0.11.1 test library and is not a reproduced real
  covariance-failure case in that installed version.

### Approved-spec excerpt for the immutable Claude plan snapshot

Authority: `docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md`, section 3c.
The following is verbatim; this plan does not replace or modify it:

> A successful winning branch does not establish that all required branches were
> resolved. Preserve per-branch outcomes through the full fit, each refit, provider
> and public inference boundary. Distinguish proved infeasibility, unresolved
> optimization, post-fit covariance/diagnostic failure, and an accepted likelihood.
> Keep branch enumeration completeness separate from optimality within a branch.
>
> T2 must refuse an unresolved required union optimum or expose an explicit status
> that prevents a valid inferential result. A best-surviving fit may remain available
> as an explicitly incomplete diagnostic. Exclude a branch only with a reasoned
> infeasibility determination, never from an error string alone. Preserve any
> usable likelihood when only covariance diagnostics fail and make the inferential
> policy explicit. If the selected medfit version cannot report completeness for a
> generic zero-product input/refit, refuse that unsupported route rather than
> inferring completeness from convergence or lack of warnings. Do not replace
> ordinary separate a=0/b=0 null fits with a singular product equality.
>
> Required controls include both partial-failure orderings, an unresolved potentially
> better branch (counterfactual discrepancy 1 versus survivor 9), optimizer versus
> post-fit errors, all-success minimum, all-failure, proved-infeasible exclusion,
> duplicate branches, and the 64-branch limit. Test status propagation into public
> objects/consumers and nested generic-product input/refit routes, not just direct
> exceptions. These controls specify future implementation acceptance; they were
> not executed as package integration tests in the proposal audit.

Section 4.8 additionally requires public and immediate/nested refit propagation,
rejection of a survivor marked complete, and successful all-success minimum.
Sections 3b/3d and 4.7/4.9–10 remain unchanged: both finite raw LRs before pooling,
matching comparisons, justified tolerance, independent df and labeled-output
controls. The author-added real-case hold remains additional to the spec.

### Ordered continuation and review contract

1. Codex: record this proposal, checklist and status only; preserve approved spec,
   implementation, saved inputs/results and unrelated untracked work.
2. Claude: one standard read-only plugin plan review of this immutable file.
   Evaluate each recommendation against the quoted approved clauses and retained
   acceptance table; identify weakening, conflated evidence or unsupported claims.
   This is not implementation/test-body approval or independent paper verification.
   Record exact inspected coverage and omissions, fingerprint and usage; no
   automatic retry/resume/budget expansion. No tests or simulations in this pass.
3. Author: rule on the three proposals. Until then keep their evidence gaps open;
   identify a qualifying pre-existing real improper-null input separately.
4. Only after separate authorization: Codex closes supported deterministic and
   dependency integration gaps, runs scoped checks and obtains implementation
   review. T5 remains unaccepted until all required gates have adequate evidence.

### Claude disposition and decision checkpoint — 2026-10-22

One snapshot-only standard review returned **needs-attention**, with medium
uncertainty. Claude found the three rulings consistent with the quoted §3c,
but did not read the owning spec, implementation, tests, papers or other files.
This is not full spec-compliance or implementation approval.

- **External dependencies / closure path:** accepted as a feasibility constraint,
  not a reason to weaken acceptance. Author chooses: (A, recommended) retain the
  approved requirements and separately authorize dependency-owner/Codex work
  producing structured branch/likelihood evidence; or (B) explicitly approve a
  narrowly stated spec amendment, with each deferred requirement named. Neither
  decision is inferred from this documentation request. If neither is authorized,
  T5 remains BLOCKED; no timeout or review verdict unlocks T6/T7. Under A, Codex
  inventories supported controls/version contracts before proposing the bounded
  implementation; under B, Codex records the exact amendment before any work.
  T6/T7 remain subject to the acceptance checkpoint and separate execution scope.
- **Real-case availability:** no exhaustive absence claim is made. An already
  stored fixture from another repository qualifies if its original data/model
  and provenance are inspectable and it reproduces the required improper-null
  behavior with the selected existing library without generating/retuning data.
  Author supplies a concrete lead; Codex verifies after separate execution
  authorization. No qualifying case means this gate remains BLOCKED indefinitely,
  not waived or replaced with synthetic evidence. No deadline is needed to
  preserve the author's explicit hold.
- **Review endpoint:** future implementation acceptance requires one explicitly
  authorized review of a frozen final code/test/spec snapshot identified by SHA
  and dependency/fixture hashes. Review must cover the full relevant clauses,
  actual test bodies and mutation harnesses; every finding must be dispositioned
  with evidence and no omitted required coverage. A blocker may stay open only
  with T5 unaccepted. Later relevant changes invalidate the affected review scope
  and need explicit authorization for another review, not automatic retries.
  This plan review does not fill historical implementation-review omissions.
- **Version mismatch:** followed up read-only after review. Current medfit source
  HEAD is `dd42073d18bc0463f31a1a0e1d469117689b5b28` (DESCRIPTION 0.10.0);
  installed library is 0.11.1 at `/private/tmp/claude-501/medfit-lib2` [MISSING 2026-10-24] (RemoteSha
  absent). Deparsing installed `.sem_fit_syntax()` confirms `.sem_vcov()` precedes
  `c(fit, list(...))` there too. This confirms covariance-before-return control
  flow for that installation, not occurrence of an escaping covariance error or
  a real improper null. Recovery evidence and any future dependency floor must
  be version-specific; package version alone is not recovery proof.
- **Stale status:** clarified the single current baseline and authorization above;
  older stages remain historical, not conflicting current assertion counts.

Review job `6fd06302-cf21-4068-a1cc-e8cf0274d219`, subject `tasks/plan.md`,
SHA256 `5f0b30ea300f7ff221574379fae5f5c838e63788bd6cbb663110a9ee1e370c54`.
Requested/effective model sonnet / claude-sonnet-5-5, standard/medium;
33,389 total tokens (3,427 output), 2 turns, 26,433 ms (API 26,038 ms),
$0.154114. Session `f347791b-766a-4b40-82c8-eea8729fa3db`.
No Evidence Lease; lease exhaustion, cost-budget exhaustion and turn-limit flags
all false. No retries, resume or budget expansion. The post-review clarifications
in this subsection and current-baseline paragraph were not re-reviewed; the
fingerprint above identifies the pre-clarification snapshot, not this final file.
No implementation/tests, installs, simulations or saved artifacts changed.

## Historical execution record (superseded only as a next-action instruction)

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
Historical stage (current baseline is in "Current state"): at `bdd03e8`, 776 deterministic assertions pass, but T5 is unaccepted: the
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

**P3 candidates ruled on (author, 2026-10-24).**
- medfit `sem_model_heywood()` at n = 50, seed 10 (`tests/testthat/helper-sem.R:208`; used in
  medfit's `test-sem-optim.R` and `test-sem-edge-grid.R`): **NONQUALIFYING.** A seeded simulator
  call generates its data, which P3 excludes. Not executed or verified (it also describes an
  improper full fit in a latent-mediator model, unchecked for a null). T5 stays BLOCKED.
- Author-authorized read-only fit screen 2026-10-24: 7 shipped or stored real datasets (lavaan PoliticalDemocracy,
  HolzingerSwineford1939 whole and by school, mediation jobs and framing, medfit mediation_demo), full + both nulls,
  medfit 0.12.0 (D4 head) and 0.13.0 (dev): **0 improper nulls**, hashes unchanged. Details and script:
  `docs/PROPOSAL-p3-stored-improper-null-leads-2026-10-24.md`, `docs/specs/p3-screen-2026-10-24.R`. T5 stays BLOCKED.
- Literature check 2026-10-24 (read-only, `~/projects/research/mbco-lrt`): Chen et al. (2001) and Gerbing and Anderson
  (1987) are both Monte Carlo studies of generated samples (Gerbing: LISREL runs from population correlation
  matrices, measurement models only; Chen: EQS/CALIS simulation of a three-latent causal chain, N = 50 and 75). Neither
  publishes a stored dataset or covariance matrix, so neither is a P3 input. Limits: Chen's extracted text is only a
  cover page, so that paper rests on the existing reading note, and its pp. 494-496 were never read.
- Bounded read-only search 2026-10-24 (file names and CSV headers across r-packages, research and
  dev-tools; no exhaustive claim): no stored improper-null input found. Literature notes and
  planning docs only.

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
simulations, saved-result changes, or merge. As of 2026-10-24 the author has also
approved pushing this branch and returning #102 to draft, and scratch-library
medfit installs were made and disclosed (see Current state); no other dependency
installs. Preserve the
unrelated untracked research-workflow plan. Recheck this plan if the approved
spec, medfit version, provider helper, fixture provenance or user constraints
change. Do not repeat broad fixture discovery without a concrete new lead.
