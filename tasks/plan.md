# T5 evidence closure plan (follow-up to merged PR #102)

Updated 2026-11-24. See the [execution checklist](todo.md).

## Reading guide

- **Live:** "Current state" (gates, decisions, baseline), P3 under "Ordered work", and "P2 direct review and findings". Other checkpoints are dated history
  kept as a record of what was reviewed and when; counts and "next action" sentences in it are superseded.
- **Authority:** the approved spec (`docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md`) is unamended; this plan
  tracks evidence for it and never changes it.

## Current state (2026-11-24)

- **D5 adapter implemented locally.** Pin medfit v0.19.0 at `2c334734c9cc89043f8ed1daddfae0d992890739`, which contains the narrowed D4 covariance-retention change. Validate the documented version-1 fit and MBCO ledgers before pooling. Both APIs preserve the affected null's identity and refuse missing, unknown, incomplete or mismatched evidence in both ARIV modes.
- **Verification.** 80 D5 assertions passed on exact v0.19.0 using explicit single starts. Eight targeted regression files passed 1,047 assertions on a scratch copy of missingmed `origin/dev` at `4272b367` with the D5 code and a scratch-only medfit single-start default. Changed-file lint, Rd and pkgdown checks passed.
- **D5 qualifying-case replay verified.** The five-imputation October case pooled on both public APIs and in both ARIV modes with one start per fit. Fixed `r4 = 2.646410449319` and own `r4 = 2.257159071191`. Each call warned only for imputation 3's improper `a = 0` null. See [the replay receipt](#five-imputation-seed-45-replay).
- **Same-engine replay agreement verified.** All 18 separate full and null fits matched provider rows, settings, diagnostics, and raw LRs on the same pins. See [the fit comparison](#same-engine-full-and-null-fit-comparison).
- **Final pinned deterministic verification recorded.** Both clean suites passed 2,158 assertions. All 32 external mutants tripped their intended assertions, and all 31 fixture-manifest entries matched. See [the final verification receipt](#final-pinned-deterministic-verification).
- **Two pinned D5 follow-up checks passed.** A consistent v1 ledger with a material negative LR was rejected in all 24 cases, and the floor-only mutant tripped all 24 rejection assertions. The stacked `a = 0` pair passed 104 assertions on typed retention and ordinary error propagation. See [the follow-up receipts](#pinned-d5-follow-up-checks).
- **Targeted P2 direct reads completed across two reviews.** The omissions-only review approved its scope. See [P2 direct review and findings](#p2-direct-review-and-findings).
- **Old-design comparison verified.** On the same single-start fixture, medfit v0.15.0 retained the ordinary covariance error at each null and pinned v0.19.0 propagated it unchanged. See [the comparison receipt](#old-design-covariance-retention-comparison).
- **Public defaults and guarded affine fallback verified.** The pinned v0.19.0 default retried and pooled the stored seed-45 case. The v0.15.0 fallback reproduced the improper null by diagnostic refit and refused ordinary covariance retention at either null. Both APIs and ARIV modes passed. See [the public API checks](#public-default-and-legacy-fallback-checks).
- **P2 findings disposition recorded.** The evidence supports the approved T5 gates on the tested pins and inputs. See [the disposition](#p2-findings-disposition).
- **Opus follow-ups verified on 2026-11-25.** The seven targeted missingmed files passed 1,033 assertions with medfit's shipped defaults. The local archive preserves the pinned sources, replay inputs, scripts, and receipts. All 86 manifest entries verified. See [the follow-up record](#opus-challenge-follow-up).
- **T5 ACCEPTED by the owner on 2026-11-25.** Acceptance covers the approved T5 gates on the tested pins. Broader D4 closure stays open. See [the acceptance record](#acceptance-checkpoint-and-downstream-tasks).
- **T6 floor and documentation verified.** medfit 0.14.0 is the minimum for the supported binary-factor path. medfit 0.19.0 remains the minimum for typed covariance retention. See [T6 verification](#t6-dependency-and-documentation).

## Historical state (2026-10-26)

- **PR #113 MERGED (2026-10-26):** squash `a4c512ef741ca208290389205d13a9117bf91772` on `dev`; SEM MBCO refuses `std.ov = TRUE` and local CI repairs landed. Local CI passed before the merge (0 errors, 0 warnings, 1 CRAN incoming note; lint and pkgdown passed). Next gate: D4 independent closure after the pending medfit covariance-retention change; D5 and the T5 checkpoint remain open.

- **PR #102 MERGED (2026-10-26):** squash `9f77220` on `dev`, 2026-10-26T20:10Z, merged by Data-Wise; 49 commits, 55
  files; final branch head `4a84e66`, tree identical to `origin/dev`. 0 reviews, 1 comment. T5 and D5 are therefore
  **follow-up gates on `dev`**, not blockers of an open PR. The merge is not recorded as authorized anywhere below
  (see the dated authorization bullet); the PR body is stale ("seven-commit", "T2–T7 unimplemented") and was left as
  a merged record. Everything below dated 2026-10-24 is otherwise unchanged and still describes the open gates.

- **Status:** T5 UNACCEPTED. P3's real-case gate is now met by the simulated seed-45 case (author ruling B, 2026-10-26, gate amended; see P3); D4 closure, D5 and the checkpoint remain open; the
  author ruled medfit's seeded `sem_model_heywood()` nonqualifying (see P3), and on 2026-10-26 reversed that (option B): a documented
  simulated case qualifies (seed 45); R3/R5 and the collaborator route are dropped. D4 is not independently
  closed; D5 is not started.
- **Open gates (2026-10-26, nothing actionable here until one moves):** (1) P3 closed by simulated seed 45 (ruling B); its D5-integration evidence is still open;
  (2) D1-D4 integration: MET 2026-10-26 by medfit 0.15.0 (read-only check: NEWS sections D1-D4, PRs #336-#342; re-landed code, the pinned `3a98bf6`/`cba4c1a` are not ancestors), not yet verified against the reviewed D1-D4 receipts;
  (3) D4 independent closure: author-authorized focused review of 0.15.0 done 2026-10-26 (read-only, one agent, nothing run): claims 1-4 supported by code and a discriminating test, no defect found, but GATE STAYS OPEN; gaps: `test-sem-post-fit-qa.R:28` asserts `winner %in% 1:2` (vacuous; verified), five untested `.sem_retain_covariance` clauses (`R/sem-outcomes.R:251-255`), no old-design comparison, suite counts unverified. Follow-up tests belong to medfit (cross-repo, needs a request); (4) D5, unblocked by (2), not started.
  R4 is the author's to send. missingmed CRAN stays live, gated on RMediation >= 1.7.1 (author hold).
- **PR #102 (as of 2026-10-24, superseded by the merge note above):** draft, base `dev`, pushed through `a20160c`. Not merged.
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

## D4 checkpoint as of 2026-10-22 (historical stage; open gates are in Current state)

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

[Amended 2026-10-26: a documented SIMULATED case with origin labeled qualifies; see the last bullet below.]
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
- Books, notebooks and Kline matrices screened 2026-10-24 (read-only, scratchpad only): Dropbox `~/Dropbox/Book/SEM/`
  (Bollen, Kline 2023, Chen and Yung 2023) and four LLM notebooks hold no stored improper-null mediation input.
  Kline Ch 9 Roth et al. (1989) path model (published matrix, N = 373; lavaan full + a/b/c/d nulls): all proper, matrix
  hash 8ca8fd44f008fefaa9b7e6e36bf512b3. Kline Ch 14 Sabatelli (2003) two-factor CFA (N = 103): FULL model improper
  (intimacy error variance -39.892), a measurement model, so nonqualifying without an author-ruled structural path
  (not authorized). Author rulings: a published matrix counts as stored input but is evidence only, because
  `medfit::fit_sem()` has no covariance input (signature check on 0.7.0, 0.12.0, 0.13.0), so P3 needs row-level data.
  Remaining routes and gate: `docs/PLAN-p3-raw-data-routes-2026-10-24.md` (reviewed; R2 named-source check first,
  R3 to R5 author-gated). T5 stays BLOCKED.
- Bounded read-only search 2026-10-24 (file names and CSV headers across r-packages, research and
  dev-tools; no exhaustive claim): no stored improper-null input found. Literature notes and
  planning docs only.
- Simulated-data mechanism check 2026-10-26 (author: no collaborator, use simulated data; **P3 wording not amended**,
  seeded data stays nonqualifying for the gate). Worktree `feature/heywood-null-research`, seed 45
  (`dev/heywood-sim.csv`, sha256 62a6984a...ca257): `a == 0` improper, full and `b == 0` proper; LR/settings agree
  and branch `a` is attributed on medfit 0.15.0 and pinned D4 0.12.0. Aggregation through `mbco_d4()` and
  `run()`/`infer()` (K=5, seed 45 at position 3, `ariv` fixed/own, both builds): one `SEM MBCO warnings:` warning
  naming `imputation 3` with `improper solution (a)`, finite `p`, clean control silent; mutants M1-M3 killed.
  Detail: worktree `docs/NOTE-heywood-null-literature-and-sim-design-2026-10-26.md` (not on dev). T5 stays UNACCEPTED.
- **Author ruling 2026-10-26, supersedes the earlier same-day option A (option B):** a documented SIMULATED case now
  qualifies as P3 evidence; the collaborator route is dropped. Qualifying case: seed 45 (`dev/heywood-sim.csv`, sha256
  62a6984a...ca257, origin SIMULATED), whose mechanism check above passed. This amends the P3 gate: the 2026-10-24
  "seeded generation is nonqualifying" ruling and the "stored input" requirement no longer apply. Limits to carry: one
  improper dataset among four clean siblings; stacked-fit outcome not recorded separately; pinned D4 build 3a98bf6 is not
  in medfit `dev`. The following replay updates the D5 evidence and records the stacked result.

#### Five-imputation seed-45 replay

Verified 2026-11-23 on missingmed `8dac15d9fbb748958e65044d178c336f931f5631` and medfit
v0.19.0 `2c334734c9cc89043f8ed1daddfae0d992890739` from scratch source archives. Used the
original seed order `1, 2, 45, 3, 4`. Seed 45 came from the stored
`feature-heywood-null-research` worktree CSV (`dev/heywood-sim.csv`, SHA-256
`62a6984af07f995328f8fdad1a483dc43c0e2f345d140b0758b145886cdca257`).
The four siblings were regenerated with the October driver and their original seeds.

Each full model and null used one optimizer start per imputation and on the stack.
Only imputation 3's `a == 0` fit used an explicit start. The replay supplied the
second perturbation from the October medfit build `9fadff9b20b7ffb198627954cd78cf5e70a327cd`
(model-derived RNG seed `1823461111`, Mersenne-Twister/Inversion/Rejection), mapped
to the adapter's labels. All other fits used their default initial vector.
Runtime tracing verified the start budget and blocked optimizer retries. A separate
default-start control had rejected seed 45's `a == 0` reduced Hessian on both
v0.15.0 and v0.19.0.

The supplied vector uses the replay model's parameter names.

```csv
parameter,start
M=~m2,-0.015365160146605647
M=~m3,0.092621658202869675
mm_a,-0.94725863718524272
y~x,-0.32276360499666262
mm_b,-0.80605398685085683
m1~~m1,1.1099659554037746
m2~~m2,0.98516196053151406
m3~~m3,0.23464242494811161
y~~y,0.59084518979911815
M~~M,0.53634429154938223
x~~x,0.72924686905101022
```

`mbco_d4()` and `run()` → `infer(type = "mbco")` returned identical results
within each ARIV mode. The stack selected `b = 0` in both modes. Own ARIV used
`a = 0` in imputation 4. Independent calculations from the branch likelihood
ratios reproduced the pooled results.

| ARIV | `r4` | `D4` | `p` |
|---|---:|---:|---:|
| Fixed | 2.646410449319 | 0.012045458409 | 0.915450739531 |
| Own | 2.257159071191 | 0.013484967866 | 0.910304801930 |

Each public call emitted one warning with this text.

```text
SEM MBCO warnings: imputation 3: improper solution: negative variance: M~~M; improper solution (a)
```

All six `a == 0` fits per call returned finite covariance. Both modes pooled
successfully and validated and attributed the improper `a = 0` fit. For
imputation 3, both modes used the `b = 0` LR in the pooled statistic.

#### Same-engine full and null fit comparison

Verified 2026-11-23 from scratch archives of missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. Separate `medfit::fit_sem()` calls
fit the full model, `a = 0`, and `b = 0` for each of the five imputations and the
stack (18 fits). Each used one optimizer start. Only imputation 3's `a = 0` null
used the recovered October vector above. Runtime checks blocked optimizer retries.

The fits and the provider used the same rows in the same order, with 100 rows
per imputation and 500 on the stack and no rows dropped. Sample hashes matched
after applying the imputation-number row-name prefixes used by the
`run()` → `infer()` stack. Model syntax, constraints, and likelihood and optimizer
settings matched across both APIs and ARIV modes.

The maximum absolute difference was zero for all 18 fit discrepancies and all
12 raw LRs computed as `n * (f_null - f_full)` before branch selection. The
adapter's raw LR agreement tolerance is `1e-7`. These separate calls used the
same medfit engine and start protocol as the provider and establish agreement
with the wrapper. The `K = 20` test supplies the independent df oracle.

| Dataset | Raw LR, `a = 0` | Raw LR, `b = 0` |
|---|---:|---:|
| Imputation 1 | 6.890089917 | 0.049607329 |
| Imputation 2 | 5.766668495 | 0.000282660 |
| Imputation 3 | 5.463181273 | 0.073946710 |
| Imputation 4 | 1.966401631 | 3.263906225 |
| Imputation 5 | 9.578136123 | 5.653238667 |
| Stack | 26.854969044 | 0.219613427 |

All 18 fits converged and returned finite covariance. The sole improper fit was
imputation 3's `a = 0` null (`negative variance: M~~M`). The provider ledger
matched the diagnostics from the separate calls, and each public call
attributed its single warning to that null. The October `heywood-sim.csv` and
the recovered `seed45-october-retry.rds` are hash-verified local inputs outside
the pinned source archives. A replay also requires those two artifacts.

### Final pinned deterministic verification

Verified 2026-11-23 from exact scratch source archives of missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. The consumer harness supplied one
start when `fit_sem()` had no explicit start count. Perturbed optimizer
starts were blocked. Both repositories stayed read-only during verification.

| Clean suite | Files | Test bodies | Passed assertions | Failures | Errors | Warnings | Skips |
|---|---:|---:|---:|---:|---:|---:|---:|
| missingmed | 7 | 73 | 1,033 | 0 | 0 | 0 | 0 |
| medfit | 8 | 79 | 1,125 | 0 | 0 | 0 | 0 |
| **Total** | **15** | **152** | **2,158** | **0** | **0** | **0** | **0** |

All 32 external mutants tripped their intended assertions, with 356 total
assertion failures (296 intended and 60 incidental across eight mutants), zero
execution errors, and zero skips. The assertion CSV lists the intended failures.
The raw logs and result CSV preserve the wider counts. The harness was
adapted in scratch to target the relocated encoding tests and shared LR-table
guards and to name the test namespace when both packages were source-loaded.

| Mutant | Intended assertion location | Intended failures |
|---|---|---:|
| `li_df` | `test-mbco-sem-acceptance.R:23, 25, 26` | 4 |
| `stack_divisor` | `test-mbco-encoding.R:13, 14, 15` | 5 |
| `tie` | `test-mbco-encoding.R:31, 33` | 2 |
| `diagnostic_labels` | `test-mbco-encoding.R:16, 24` | 4 |
| `dimensions` | `test-mbco-encoding.R:43` | 2 |
| `factor_limit` | `test-mbco-sem-acceptance.R:208` | 1 |
| `improper_payload` | `test-mbco-sem-acceptance.R:219, 222` | 2 |
| `encoding` | `test-mbco-sem-acceptance.R:180` | 26 |
| `syntax` | `test-mbco-sem-acceptance.R:463` | 3 |
| `null_identity` | `test-mbco-sem-acceptance.R:447` | 8 |
| `null_lr_match` | `test-mbco-sem-acceptance.R:332` | 2 |
| `full_fixed_x` | `test-mbco-sem-acceptance.R:404, 412` | 10 |
| `null_factors` | `test-mbco-sem-acceptance.R:404, 412` | 10 |
| `null_fixed_x` | `test-mbco-sem-acceptance.R:404, 412` | 10 |
| `survivor_complete` | `test-mbco-sem-acceptance.R:104` | 48 |
| `table_converged` | `test-mbco-sem-acceptance.R:104` | 36 |
| `table_finite` | `test-mbco-sem-acceptance.R:104` | 12 |
| `empty_improper` | `test-mbco-sem-acceptance.R:447, 454, 455` | 14 |
| `null_nobs` | `test-mbco-sem-acceptance.R:332` | 1 |
| `lr` | `test-mbco-sem-provider.R:15, 21, 22, 24` | 7 |
| `completeness` | `test-mbco-sem-provider.R:32, 35` | 9 |
| `labels` | `test-mbco-sem-provider.R:87, 91` | 7 |
| `feasibility` | `test-mbco-sem-provider.R:272, 275` | 4 |
| `args` | `test-mbco-sem-args.R:60, 62, 65, 69, 71` | 33 |
| `d4_root_attribution` | `test-sem-post-fit-qa.R:23` | 2 |
| `d4_child_notices` | `test-sem-post-fit-qa.R:49, 50` | 2 |
| `d5_wrong_null` | `test-mbco-sem-ledger.R:41` | 8 |
| `d5_unknown_schema` | `test-mbco-sem-ledger.R:72` | 8 |
| `d5_unresolved_child` | `test-mbco-sem-ledger.R:72` | 4 |
| `d5_sample_hash` | `test-mbco-sem-ledger.R:72` | 4 |
| `d5_settings` | `test-mbco-sem-ledger.R:72` | 4 |
| `d5_raw_lr` | `test-mbco-sem-ledger.R:72` | 4 |

The `empty_improper` mutant emitted both mutation-run warnings. The first was
at the `mbco_d4()` refusal assertion and the second at the `infer()` refusal
assertion (lines 454 and 455). Both warning messages were identical.

The incidental failures were `improper_payload` 15, `encoding` 10,
`null_identity` 2, `lr` 7, `completeness` 5, `labels` 6, `feasibility` 5,
and `args` 10.

```text
SEM MBCO warnings: imputation 1: improper solution: null variance; imputation 2: improper solution: null variance; the stacked data: improper solution: null variance
```

All 31 SHA-256 entries matched before and after. The before and after manifests
each had SHA-256 `87da38ff64f08646a633be98ad6a7a242ecf824ee8de8f7029c1c4da2e44a125`.

| Stored input | Unchanged SHA-256 |
|---|---|
| medfit `memory_exp.rds` | `ec778dc6503cb6ad0351b0dd8ce47b03c3e16ad0f67212512b263aa1f2acdccd` |
| missingmed `mbco-d4-medsim-0.5.1.rds` | `b88d9e26e462f6f387ea711766511507f8c638939f18d95ddab67c640964e4e8` |
| October `heywood-sim.csv` | `62a6984af07f995328f8fdad1a483dc43c0e2f345d140b0758b145886cdca257` |
| Recovered `seed45-october-retry.rds` | `c17e6ebe4881e4c625cf094041f8a526568ed259a5ec692d16ccaa00076a0e7c` |

The per-file counts, exact failed assertion messages, and complete manifests
are in the local scratch receipt at `/private/tmp/t5-final.OP8Mt2/T5-verification.md`.
See [P2 direct review and findings](#p2-direct-review-and-findings) for review
coverage. See [the owner decision](#acceptance-checkpoint-and-downstream-tasks).

### Pinned D5 follow-up checks

Both checks source-loaded the same scratch archives with single starts and
blocked optimizer retries. The pins were missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. Both repositories stayed read-only
during execution, and all 31 fixture SHA-256 entries matched before and after
each check.

#### Consistent v1 ledger with a material negative LR

Starting from a genuine medfit MBCO response, the control set one null's
discrepancy below the full fit and updated the ledger and LR table consistently.
Each injected ledger passed validation and reached the LR guard with a planted
raw LR of approximately `-0.001`. `mbco_d4()` and `infer(type = "mbco")`
refused both nulls at each of two imputations and at the stack, in `fixed` and
`own` ARIV modes. Each error named the dataset and null.

The original run passed 52 assertions. The floor-only mutant changed only the
handling of material negative LRs to return zero. It pooled in all 24 cases
and failed all 24 intended `expect_error()` assertions at
`test-negative-ledger.R:71`. The other 28 assertions passed. Both runs had zero
execution errors, warnings, or skips. The test and both logs are in the local
scratch directory `/private/tmp/t5-negative-lr.uVi1Y2/`.

#### Paired covariance failures at the stacked null

The clean and two fault runs used the same two completed datasets assembled
from stored `iris` rows. Both faults were injected at `.sem_vcov()` for the
240-row stacked `a = 0` fit, with the same rows, model, and fitted parameters.
The typed `information_not_pd` diagnostic retained the likelihood in the v1
ledger and left both raw LRs and the complete pooled result identical to the
clean run in both APIs and modes (`r4 = 2.84326984096`). Each typed run emitted
exactly one warning.

```text
SEM MBCO warnings: the stacked data: a = 0 covariance-stage failure: injected stack covariance failure; likelihood retained, covariance unavailable
```

The ordinary error with the same message escaped medfit unchanged. Both APIs
refused at the stack in both modes, returned no pooled result, and emitted no
warning.

```text
Fitting the MBCO models failed in the stacked data: injected stack covariance failure
```

All 104 assertions passed, with zero failures, execution errors, unexpected
warnings, or skips. The run captured and asserted the four expected typed
warnings. The test and log are in `/private/tmp/t5-stack-pair.3JPex3/`.

These scratch checks supply the two targeted controls identified in the
bounded review. The test files live outside the package's CI suite. T5 remains
UNACCEPTED.

### P2 direct review and findings

Two bounded Claude reviews covered missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. The first (`e4ecb890`,
needs attention) directly read the approved spec, principal test and
implementation bodies, original mutation harness, and both follow-up
controls and logs. The omissions-only review (`65be00b1`, approve for its
scope) directly read the remaining targeted argument, label, branch,
certificate, and covariance bodies, the retention source, public help,
plan receipts, mutation CSVs, fixture manifests, and fit comparison. Together
they complete the targeted P2 direct reads. T5 sign-off is a separate checkpoint.
Both review receipts and their exact coverage are in the local scratch directory
`/private/tmp/t5-final.OP8Mt2/` as `T5-P2-Claude-direct-review.json` and
`T5-P2-Claude-omissions-review.json`.

- **Pinned controls.** The original `c(4, -1)` injection places the negative
  on the smaller LR. For a fixed-mode imputation whose non-selected null is
  invalid, use the new consistent-ledger control. It injects each null
  separately with the stacked branch selection intact. The five D5 ledger
  mutants share a rejection assertion. More specific per-field messages and
  stronger optional label and mixed-certification tests remain follow-ups.
- **Evidence scope.** The deterministic runs used single starts. The focused
  [public API checks](#public-default-and-legacy-fallback-checks) exercise the
  shipped multi-start default on stored inputs. Adding the two scratch controls
  to CI remains a separate follow-up.
- **Old-design provenance.** The archived old `DESCRIPTION`, `R/sem-fit.R`,
  `R/sem-mbco.R`, and `memory_exp.rds` match medfit v0.15.0
  `e068d7506c6263dcda7f5485c09f892249165fbf`. The fixture has the same hash as
  the v0.19.0 candidate copy. The saved pinned v0.19.0 `anova-probe.log` records
  LR agreement, both `anova()` refusals, and propagation of the ordinary error.
  The fresh [old-design comparison](#old-design-covariance-retention-comparison)
  supplies the older build's executed receipt.

### Old-design covariance retention comparison

On 2026-11-24, fresh R processes source-loaded medfit v0.15.0
`e068d7506c6263dcda7f5485c09f892249165fbf` and v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739` from Git archives. Each fit used one
start, with an `rnorm()` trap for random retries. Both versions used the same
369-row `memory_exp.rds` and injected the ordinary `.sem_vcov` `simpleError`
`injected internal allocation failure` separately at each null.

| medfit | `a = 0` | `b = 0` |
| --- | --- | --- |
| v0.15.0 | Retained likelihood, recorded `covariance = "failed"`, and emitted one `medfit_sem_covariance_notice`. | Retained likelihood, recorded `covariance = "failed"`, and emitted one `medfit_sem_covariance_notice`. |
| v0.19.0 | Propagated the identical `simpleError` with zero warnings and no MBCO result. | Propagated the identical `simpleError` with zero warnings and no MBCO result. |

The clean baselines agreed exactly across pins (raw LRs `221.04554608529347`
and `3.4172105424343622`, MBCO p-value `0.06451994756817192`). Each v0.15.0
retention run preserved both raw LRs and the p-value. The before and after
fixture SHA-256 matched (`ec778dc6503cb6ad0351b0dd8ce47b03c3e16ad0f67212512b263aa1f2acdccd`).
Both repos were read-only during the run. Scratch receipts are `compare.R`,
`medfit-0.15.0.log`, and `medfit-0.19.0.log` in
`/private/tmp/t5-old-design.afsX7V/`. The public missingmed behavior is covered by
the follow-up below.

### Public default and legacy fallback checks

On 2026-11-24, fresh R 4.6.2 processes source-loaded missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739` or v0.15.0
`e068d7506c6263dcda7f5485c09f892249165fbf` from Git archives. Both
`mbco_d4()` and `run()` followed by `infer(type = "mbco")` used `fixed` and
`own` ARIV. Inputs were two 184-row blocks of alternating rows from
`memory_exp.rds` and, for the retry check, two copies of the stored 100-row
seed-45 CSV. No imputed values were generated and no start was overridden.

- **v0.19.0 shipped default.** All eight untraced calls pooled. Observation-only
  reruns matched their outputs and warnings and confirmed three complete v1
  MBCO ledgers per call with a five-start budget on the full and null fits.
  `memory_exp.rds` used nine solver calls per public call and emitted no warnings.
  Seed 45 used 15 solves per public call. Its `a = 0` fits in both imputations
  and on the stack failed the first reduced-Hessian check and accepted
  `perturbed start 2 of 4`. Each call emitted one aggregated warning naming
  those three improper `a = 0` nulls. The caller's RNG state was unchanged.
- **v0.15.0 guarded affine fallback.** All four clean `memory_exp.rds` calls
  pooled without warnings. The four seed-45 calls pooled after 24 matching
  diagnostic refits in total, two per dataset per call, and each emitted one
  aggregated warning naming the improper `a = 0` nulls. Injecting the ordinary
  `.sem_vcov` error separately at imputation 1's `a = 0` and `b = 0` nulls
  refused pooling in all eight API/mode/null combinations with
  `SEM covariance retention requires medfit >= 0.19.0.` and no warning.

The logged pooled statistics agreed across both APIs, modes, and builds for
each fixture (`r4 = 0.831413516655587` on `memory_exp.rds` and `r4 = 0` on
seed 45). All three input-file hashes matched before and after. Both repos were
read-only during the checks. Scratch receipts are `check.R`, `medfit-0.19.0.log`,
and `medfit-0.15.0.log` in `/private/tmp/t5-public-defaults.KpEHnx/`.

### P2 findings disposition

Checkpoint review on 2026-11-24 against the approved spec and acceptance
criteria, on missingmed `8dac15d` and the medfit pins above. The latest
committed and working-tree changes since the tested missingmed pin are
documentation only. No fits, mutations, or external reviews were rerun for
this disposition. The two Claude receipts establish their stated review
coverage. The later comparison and public-API receipts were checked locally.

| Review finding | Disposition |
| --- | --- |
| Shipped multi-start path untested | The [public default check](#public-default-and-legacy-fallback-checks) observed retry and v1 ledger validation and preserved RNG state in both APIs and ARIV modes. The [seven targeted test files](#opus-challenge-follow-up) also passed with unmodified defaults. The two-copy seed-45 stress case and the five-imputation single-start replay exercise different setups. |
| Negative-LR and stacked-null controls are scratch-only | Accepted as executed T5 evidence for §§3b–3c. The [two receipts](#pinned-d5-follow-up-checks) identify the scripts, pins, exact assertions and outcomes. Porting them into the test suite remains a regression-coverage follow-up. |
| Replay used a recovered start and same-engine fits | The [18-fit comparison](#same-engine-full-and-null-fit-comparison) establishes wrapper agreement, including rows, settings, LR and diagnostic identity. The recovered start is part of that replay's setup. The separate default run demonstrated a native retry. These receipts do not establish global optimality or independent-engine parity for the improper null. |
| Material-negative non-selected branch mislabeled | Use the [consistent-ledger control](#consistent-v1-ledger-with-a-material-negative-lr) for item 7. It injects each branch in turn with the fixed-mode stack selection intact, so one injection targets the non-selected branch. The older `c(4, -1)` example puts the negative on the smaller LR. |
| Old-design probe unpinned and legacy wrapper behavior untested | Resolved on the two pins. The [direct comparison](#old-design-covariance-retention-comparison) records both nulls on both versions. The [v0.15.0 public fallback](#public-default-and-legacy-fallback-checks) pools clean fits, attributes improper nulls through matched refits, and refuses covariance retention at either null. Other pre-v0.19 builds were not exercised in this check. |
| Incidental mutation failures undisclosed | Resolved in the [deterministic receipt](#final-pinned-deterministic-verification). The CSV records 356 total failures, 296 intended and 60 incidental across eight mutants. All 32 mutants tripped their intended assertions, with zero execution errors or skips. |
| Five ledger mutants share a generic rejection assertion | The targeted body and each isolated mutant support the required refusal behavior. Field-specific error assertions remain an optional diagnostic improvement. |
| Two replay inputs are outside the Git archives | The stored CSV and recovered start are preserved with the Git source archives and replay scripts in the [verified local archive](#opus-challenge-follow-up). |
| Mixed certified/failed branch order and weak label assertion | Both failure orderings required by item 8 are exercised in medfit `test-sem-outcomes.R` (the partial-failure and survivor-mutant bodies). Reversing the order within the mixed certificate case adds coverage. The tested-term modifier assertion in missingmed `test-mbco-sem-label.R` remains an optional assertion-strength improvement. |

The adjacent spec items remain visible for the broader migration review. In
§3/C1, the duplicate-row rule is ambiguous for repeated source terms because
lavaan collapses them before missingmed counts rows, including a repeat with a
different label. The owner should confirm the intended rule before changing
the parser or the spec. In §4.1, named refusal of `auto.cov.y` has a mutation
receipt. The specific option-pass-through mutant against the lavaan parity
oracle remains unverified. Both are outside the items 7–10 T5 controls.

The existing evidence supports likelihood validity, branch completeness,
historical df and output compatibility, diagnostic attribution, the amended
stored-case gate, and pinned verification. The targeted P2 reads and this
disposition support the [owner's acceptance decision](#acceptance-checkpoint-and-downstream-tasks).

### Opus challenge follow-up

The bounded read-only Opus review returned inconclusive, leaning ready, with
no demonstrated defect. It flagged the forced single-start suite, temporary
evidence storage, and the scope of the replay claim. It reviewed selected
receipts directly and relied on the two P2 reviews for the approved spec,
medfit source, and most test bodies. No specific approved T5 requirement was
identified as needing a separate D4 sign-off.

On 2026-11-25, the seven targeted missingmed test files ran in a fresh R process
from exact Git archives of missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. The runner used the shipped medfit
defaults with no `fit_sem()` trace or retry trap. All 1,033 assertions across
73 test bodies passed, with zero failures, errors, warnings, or skips. The
caller's RNG state and all 31 fixture SHA-256 entries were unchanged. Both
repositories stayed read-only during the run. The 32 mutant results remain
evidence from the separate single-start run.

The local archive at
`/Users/davood/projects/r-packages/evidence/missingmed/t5-2026-11-25/`
preserves the pinned sources, seed-45 CSV, recovered start, replay and 18-fit
scripts and receipts, mutation harnesses and results, P2 and Opus reviews, and
shipped-default runner and results. Its `README.md` indexes the files and
`ORIGINS.tsv` maps original paths. All 86 entries in `SHA256SUMS` verified
after copying. The archived scripts retain their original paths, which can be
pointed to the bundled inputs in a scratch replay.

### Acceptance checkpoint and downstream tasks

On 2026-11-25 the owner accepted T5 on missingmed
`8dac15d9fbb748958e65044d178c336f931f5631` and medfit v0.19.0
`2c334734c9cc89043f8ed1daddfae0d992890739`. The decision is based on the mapped
passing evidence, the amended stored-case gate, the two P2 direct reviews
taken together, and the Opus follow-up checks. The broader independent D4
closure stays open.

### T6 dependency and documentation

On 2026-11-25, the original 0.10.0 floor candidate passed 932 assertions and
produced three errors when SEM inputs used a binary factor. medfit 0.14.0
(`b7d7566328e6b97368409a2b64344a1d220c27ae`) introduced SEM factor
encoding and passed all 953 applicable assertions across six targeted files.
With the updated floor and unchanged shipped starts, pinned medfit 0.19.0
passed all 1,033 assertions across seven files. Both final runs had zero
failures, errors, warnings, or skips in the files selected for that version.
The ledger test file applies to 0.19.0 and later.

`DESCRIPTION`, NEWS, the SEM provider guard, help, and vignettes now use the
0.14.0 minimum. The guarded affine path still supports older medfit versions
within the new floor. Typed covariance retention requires medfit 0.19.0 or
later. CRAN offered medfit 0.3.2, and the Data-Wise R-universe offered 0.20.0
when checked. The development installation instructions include the Data-Wise
repository. The checked source versions were 0.14.0 and the accepted 0.19.0
pin.

### T7 execution scope

`make ci` invokes `dev/local-ci.sh`, which runs a full R CMD check. That
includes tests that generate data and vignettes that generate data and impute
missing values. The full runner was held under the existing execution limits.

The R CMD check, lint, and pkgdown workflows now add Data-Wise R-universe
through `setup-r`. A local pak resolution selected medfit 0.20.0, RMediation
1.11.1, and S7 1.0.0. Hosted execution is pending.

The published medfit 0.20.0 source (`4739e8e76020cd7d0e5f8f29e9d918c6dd4e6ef8`)
was loaded in scratch with installed RMediation 1.6.1 and S7 0.2.2.
The seven focused test files passed 1,033 assertions with zero failures,
errors, warnings, or skips. The source tarball built with vignette builds
disabled, actionlint passed, lintr reported zero lints, and the pkgdown index
check passed with 15 Pandoc `--mathml` deprecation warnings.

On 2026-11-25 the author authorized scratch installs and the full runner,
including data-generating tests and vignettes, with no push. The run used a
clean archive of missingmed `5de579e747adfbb76c06283a438f35487d7fe995` on
macOS arm64, R 4.6.2. The scratch medfit 0.20.0 and S7 1.0.0 installs
loaded. An initial pak rebuild of nloptr 2.2.1 failed to link against
`emutls_w`, so the run reused the installed nloptr 2.2.1.

RMediation 1.11.1 (`2b3907a16cb329cca32dc4d1b5919d8b8af62e1c`) failed
to install under S7 1.0.0. Sourcing its class definitions reproduced the
failure in `S7::S4_register(MBCOResult)` at `R/00_classes.R:303`.
The same RMediation source installed under S7 0.2.2 in a separate scratch
library and then failed to load under S7 1.0.0. With all three resolved
versions selected, `make ci` exited 2 during `R CMD build`: RMediation's
`.onLoad` failed on an unregistered S4 class union while installing
missingmed for vignette builds. No vignettes, tests, lint, or pkgdown checks
ran in this invocation. Scratch logs are in
`/private/tmp/missingmed-t7-ci.pHL016/` (`ci.log`, `install-exact.log`,
`runtime-exact.log`, and `union-trace.log`).

The follow-up used the published CRAN RMediation 1.6.1 source, S7 1.0.0,
and the same medfit 0.20.0 archive in a fresh scratch library. All three
installed and loaded together. `RMediation::medci()` returned the finite
95% interval `[0.08723788, 0.33999687]` for the smoke input. The three
source hashes are in `/private/tmp/missingmed-t7-compatible.XXai6i/source-sha256.txt`.
This is a compatible local test combination. Hosted dependency resolution
still selects the incompatible RMediation 1.11.1.

On the clean `5de579e` source with these versions, `make ci` installed
missingmed for the vignette build and exited 2 while rendering
`mbco-mi.Rmd` (result chunk) and `technical.Rmd` (sensitivity-grid chunk).
Both failed with `could not find function "tidy"`. Under S7 1.0.0,
the three `S7::method(tidy, ...) <-` assignments bind an external-generic
sentinel to missingmed's exported `tidy`. `broom::tidy` remains callable.
A scratch-only control called `` S7::`method<-` `` directly
for all three methods. The exported generic was again identical to
`broom::tidy`, and both failing vignettes rendered. The source checkout
retains the original code. Separate lintr and pkgdown index checks passed
on the unmodified source, with zero lints and 15 Pandoc deprecation
warnings during pkgdown. See `/private/tmp/missingmed-t7-compatible.XXai6i/`
for `ci.log`, `tidy-probe.log`, and `tidy-control-render.log`.

On the unmodified source and same three versions, the separate
`R CMD check --as-cran --no-manual --ignore-vignettes` reported zero errors,
zero warnings, and one CRAN incoming feasibility note. It passed 2,489
assertions with zero failures or warnings and 10 skips: eight CRAN-mode
skips, one for absent regmedint, and one for the refcard outside the built
package. See `check-no-vignettes.log` and the `testthat.Rout` under the
scratch check directory.

The verified `tidy()` change and NEWS entry are in local commit `9df4578`.
Full `make ci` passed in scratch with RMediation 1.6.1, S7 1.0.0, and
medfit 0.20.0. It built and rechecked all four package vignettes.
R CMD check reported zero errors, zero warnings, and one CRAN incoming
feasibility note. The suite passed 2,489 assertions with zero failures
or warnings and the same 10 skips. Lintr reported zero lints and the
pkgdown index passed with 15 Pandoc deprecation warnings. A separate
S7 0.2.2 check verified the callable re-export and passed all 176 assertions
in the focused S7 class test file. Logs and source hashes are in
`/private/tmp/missingmed-t7-tidy.UVzx14/`.

Local commit `8394fdf` adds `RMediation@1.6.1` to the R CMD check,
lint, and pkgdown workflow dependency inputs. In scratch, the workflow
inputs and action defaults were passed to `pak::lockfile_create()` with
pak 0.11.1, empty user and site libraries, Posit Package Manager's Noble
repository, and Data-Wise R-universe. Each lockfile resolved RMediation
1.6.1, S7 1.0.0, and medfit 0.20.0. All three resolved sources downloaded.
The medfit archive matched the tested SHA-256. The RMediation and S7
archives matched the tested source trees apart from repository metadata
and the corresponding MD5 manifest. Actionlint passed all three files.
Scratch lockfiles and the resolver log are in
`/private/tmp/missingmed-t7-ci-pin.eUMhWh/`.

On 2026-11-25, all three hosted workflows passed on `dev` in the separate
private `Data-Wise/missingmed-t7-ci-8394fdf` repository. GitHub reported
`8394fdfe690a5b449498c9b66a7ac7b8b18af2a2` as the head SHA for each run.
The dependency logs show RMediation 1.6.1, S7 1.0.0, and medfit 0.20.0
installed in all three runs.

- R CMD check reported `Status: OK`. [Run](https://github.com/Data-Wise/missingmed-t7-ci-8394fdf/actions/runs/45678848975)
- Lint found no lints. [Run](https://github.com/Data-Wise/missingmed-t7-ci-8394fdf/actions/runs/45678849268)
- pkgdown built the site. GitHub marked the Pages deployment step **Skipped**. [Run](https://github.com/Data-Wise/missingmed-t7-ci-8394fdf/actions/runs/45678849028)

T7 remains open at the author's request.

## Boundaries and invalidators

The author authorized targeted evidence-gap fixes and a fresh bounded review;
no broader branch-enumerator design or spec amendment is inferred. No
saved-result changes. #102 is merged (see Current state); push approvals and the
scratch-library medfit installs are disclosed there; no other dependency installs.
Simulation: the author-approved October seed-45 mechanism checks and November
replay of the four fixed siblings ran in scratch (see P3). Any new simulation
needs a fresh request. The research-workflow
plan is committed (`87ea8e4`) as a record, unreconciled. Recheck this plan if the approved
spec, medfit version, provider helper, fixture provenance or user constraints
change. Do not repeat broad fixture discovery without a concrete new lead.
