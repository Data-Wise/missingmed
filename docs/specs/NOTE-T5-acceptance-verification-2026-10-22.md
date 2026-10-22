# T5 deterministic acceptance coverage — 2026-10-22

Initial status at `25912b2`: partial; T5 was not fully accepted. Approved spec unchanged.
PR #102, local branch `feature/lavaan-mbco-medfit`, starting head `566b894`.

## Coverage and confirmed repairs

`test-mbco-sem-acceptance.R` adds 443 passing assertions. Together with label
(39), provider (124), arguments (52), and public lavaan (31) tests: 689 assertions,
zero failures, errors, warnings, or skips. The final acceptance-only rerun followed
the other four suites; no production logic changed between these runs.

- Independent K=20 rational oracle distinguishes Chan–Meng nu=76 from Li's
  20884/361; K=3 alone cannot distinguish these formulas. Near-zero r4 thresholds,
  stacked division, branch ties, dimensions, diagnostics, and label swaps covered.
- Both public APIs and both ARIV modes reject negative/nonfinite LR, incomplete
  branch collections, optimizer/postfit failures, and full-fit failure payloads.
- Stored SEM/GLM parity uses the existing frozen fixture without altering it:
  SEM/GLM tolerance 1e-7, stored vectors 1e-10. Parallel mediators and a latent
  model with a direct indicator effect agree with separate equality-null fits.
- Binary covariate factors match numeric coding; unsupported three-level factors
  are explicitly refused. A newer medfit accepting them does not expand the spec.
  Unused binary levels on a constant column still fail closed.
- Actual medfit character-vector improper payloads are preserved and warnings
  aggregated once per dataset; silent payloads are tested too.
- Structural checks reject c(a), label("a"), and multi-lhs syntax before lavaan
  normalizes away their original form. Generic product unions, aliases, duplicate
  products and 64/128-combination examples are refused, not falsely certified as
  complete branch enumeration.

Nine acceptance mutations detected: Li df (4), stacked divisor (39), tie (3),
diagnostic labels (20), dimension checks (2), factor scope (1), improper payload
(4), encoding (32), syntax (3). These counts precede the final 46 assertions;
the same production logic was used. The five existing provider mutations were
also detected; these are deterministic, in-memory defects, not simulations.

## Environment and reproducibility

Existing library only: `R_LIBS=/private/tmp/claude-501/medfit-lib2`, medfit 0.11.1,
built R 4.6.1, 2026-10-21 04:50:02 UTC, unix. RemoteSha absent; no source commit
identity is claimed. Installed lazy-load SHA256:

- `medfit/R/medfit.rdb`: `8f0a2c7e6719935753715a59a7dc86e63ef9c00a72cf633e27106e760425c217`
- `medfit/R/medfit.rdx`: `801cbbf95c240f996ea9ca696a42575e7ccc3fe68750dc6108200cdb3db93bab`

Use `devtools::load_all()`, explicitly source
`tests/testthat/helper-legacy-mbco.R`, then test the five files above with
`testthat::test_file()`. Mutation scripts are
`dev/check-sem-provider-mutations.R` and `dev/check-sem-acceptance-mutations.R`.
Complete-data mids construction restores RNG state; no data are generated or
imputed. Legacy helper parity is not independent df evidence.

Help regenerated with devtools::document(); pre-existing unresolved IPW links
remain (.ipw_weights twice, .ipw_weights_info once). No dependency installation,
simulation, saved-result modification, full random-data suite, package check,
vignette render, push, or merge performed. T6 package/dependency gates remain.

## Claude review and limitations

Plugin standard/medium review job `e88971fe-e257-4016-8127-dc46ca5b8480`, effective
model claude-sonnet-5-5, returned needs-attention. It ran the acceptance file green
but did not execute mutation scripts. Crucially, it skipped the approved spec,
the frozen fixture, legacy helper, and existing SEM tests: not a spec-compliance
approval. No automatic second review or budget expansion was attempted.

Confirmed review blocker repaired afterward: the independent df test no longer
reads source-tree-only documentation excluded from package builds; it derives
the rational oracle directly. Added silent-payload and unused-level tests.
Later syntax repairs and final coverage additions were tested locally but were
not re-reviewed by Claude.

Remaining acceptance gate: null-fit improper warnings lack reliable branch
identity. Warning retention is tested; per-null attribution is not established.
Inferring identity from warning order is unsafe when only one branch warns.
Resolving this needs structured dependency diagnostics or an approved alternative
provider strategy. Real random-data Heywood reproduction and multistart/global
optimality are not established by these deterministic controls. A postfit error
that prevents medfit returning a likelihood remains a closed failure, not a
recoverable best-survivor result.

## Null-warning attribution follow-up

The section 3 separate-exported-fit alternative resolves the attribution gap
without treating warning order as branch evidence. `mbco_sem()` remains the LR
source. Only an improper warning emitted during its null refits triggers two
additional `fit_sem()` diagnostic fits. These use the full model's information,
start count, control and meanstructure handling, always `fixed_x = FALSE`, and
the original dataset. Full-fit warnings do not trigger this fallback.

Both null samples and raw LR values must match the original comparison within
the existing absolute 1e-7 tolerance. Branch labels come from each fit's improper
diagnostics, not the number or order of warnings. A mismatch, diagnostic error,
or failure to reproduce any improper null stops inference; no new LR is selected.
No medfit private function or namespace mutation is used in production.

Red test evidence: before implementation, the public warning lacked `(b)` and
the diagnostic-refit seam did not exist. A subsequent stored binary-factor test
failed because `SEMFit@data` contains expanded columns whereas model syntax
still names the original factor. Passing the original dataset corrected this;
do not reconstruct these fits using expanded data without medfit's factor map.

Deterministic results: acceptance file 530 assertions, label 39, provider 124,
arguments 52, public lavaan 31: **776 passing assertions**, no failures, errors,
warnings, or skips. Separate-null discrepancy checks cover numeric/binary
covariates with implicit/explicit means on stored iris data. Injected diagnostics
cover a-only, b-only and both improper states with a single warning through both
public APIs and both ARIV modes. Sample/LR mismatches, missing reproduction and
diagnostic errors refuse inference. This is not a new real-Heywood fixture or
global-optimality proof. Documentation generation retains the pre-existing IPW
link warnings noted above. Full random-data/package suites remain unrun.

Follow-up Claude job `1747f2d2-b341-479f-a358-69109bffbbc9` explicitly read the
approved spec lines 1–255 (including every relevant section), compared installed
`medfit::mbco_sem` source, and ran the acceptance file green. Verdict:
needs-attention, uncertainty medium; no full spec-compliance approval. It did not
inspect the full 3c/3d or 4.7–10 test bodies beyond the diff, help or vignette.
The remaining spec lines 256–263 are tracking-issue links, not fitting policy.

Findings and disposition:

- Real improper-null stored-data proof absent: confirmed evidence gap. Existing
  medfit Heywood tests generate data and were not run. Two stored-data model
  probes did not yield diagnostic improper flags; neither proves the desired
  behavior. Keep T5 acceptance pending and label injected evidence explicitly.
- Factor/fixed-x option parity concern: original data are necessary for the
  exported API, which cannot accept the private factor map. Added exact equality
  checks for rebuilt factor and fixed-x state; require the approved no-fixed-x
  state before refitting. Numeric/binary and meanstructure LR oracles pass.
  Installed `.sem_optimize` emits the improper warning from the same `improper`
  vector it returns; `.sem_as_semfit` transfers that vector into diagnostics.
  This is control-flow support, not a real improper-fit acceptance case.
- Empty non-NULL `mb$improper` bypass: confirmed. Regression control produced 14
  failures before changing the gate from `is.null` to zero length. Final tests
  pass. These guards and the empty-vector repair followed Claude review and were
  not automatically re-reviewed; no retry/resume or budget expansion occurred.

Requested/effective model: sonnet / claude-sonnet-5-5, standard/medium. Usage:
270791 total tokens, 5960 output, 12 turns, 60263 ms (API 51528 ms), $0.206959.
No Evidence Lease; evidence-lease, cost-budget and turn-limit exhaustion flags
all false. Session `ed091cc8-1916-4cbb-b4e5-ccd789bf4c43`; resume hint:
`claude --resume ed091cc8-1916-4cbb-b4e5-ccd789bf4c43`.
Recommended focused follow-up: real improper-null stored input and the remaining
section-to-test review map. This review did not establish global optimality.

Local coverage map (not a substitute for Claude's omitted body inspection):

| Spec | Deterministic controls |
|---|---|
| C5 / section 3 | Acceptance tests beginning lines 294, 309, 339, 356: branch labels, LR/sample matching, exported refit parity, both public APIs/modes; real improper-null case remains open |
| 3b / 4.7 | Provider tests at lines 1, 86, 103; acceptance line 44: every dataset/branch, nonfinite/negative summaries and roundoff boundary |
| 3c / 4.8 | Provider lines 113, 156, 246, 259, 272; acceptance lines 72, 149, 418: partial failures, generic-union refusal, affine feasibility, full-fit propagation; no generic union ledger/global certificate |
| 3d / 4.9 | Acceptance lines 17, 33, 173: independent K=20 Chan–Meng/Li rational answers, zero ARIV/gap threshold, frozen fixture provenance |
| 4.10 | Acceptance line 114 plus mutation harness: encoding, stack/K, own/fixed, ties, labeled diagnostics and dimensions |

At that earlier checkpoint, 16 mutation controls detected defects: five provider controls
plus eleven acceptance controls. The two added controls force warning-order-like
identity (10 failures) and remove LR matching (2 failures); final acceptance
mutation counts are 4/39/3/20/2/2/17/32/3/10/2 in script order.

Targeted lint passes with `devtools::load_all()` before linting; without loading,
the standalone `R/infer.R` linter falsely reports the package-internal provider
as undefined. Approved spec and saved fixtures remain unchanged. No installs,
simulations, push, or merge. Local implementation does not imply T5 acceptance.

## Existing-fixture search and rerun — 2026-10-22

At starting head `068f075`, no qualifying stored improper-null fixture was found
in the bounded searches below. This is a search result, not proof that no such
artifact exists elsewhere. No data generator or simulation was run, and no
saved input/result was changed or replaced with a newly manufactured case.

- missingmed: all four discovered RDS files; the checked-in MBCO fixture supplies
  observed mediation inputs, while the other three are IPW cells/truth files.
- Active medfit and `/private/tmp/claude-501/medfit-dev`: four checked-in stored
  data/fixture files per checkout. Inspected `sem-v080-frozen.rds`: observed,
  weighted-sandwich and constrained observed models, not a latent improper-null
  fixture. `memory_exp.rds` contains a 369-row observed mediation dataset;
  `lavaan-simple-before-aliases.rds` contains estimates/vcov, not raw null data.
  The existing Heywood test calls `sem_sim(..., 50, 10)`; it was not executed.
- Scratch: filename/content discovery under `/private/tmp`, relevant medfit
  directories and macOS temporary directories; metadata/library trees excluded
  in narrowed searches. Broad searches hitting result caps were narrowed, not
  treated as exhaustive. Existing M5 latent-input candidates contain a 50-row,
  three-variable observed dataset and numerical-profile outputs, not an
  identified improper-null SEM case. Those inputs/outputs were read only.
- No named heywood/improper artifact found under `.codex` excluding plugin and
  module trees. Companion research stored-file discovery showed scenario truths
  and comparator outputs, not an identified improper-null fixture; no manuscript
  content or outputs were edited.

Rerun on the unchanged implementation with existing medfit 0.11.1: 776 assertions
pass (39 + 124 + 52 + 31 + 530), zero failures/errors/warnings/skips. Full random
suite, `make ci`, simulations, dependency installs and rendering remain unrun.
The approved spec permits the exported-fit diagnostic alternative, and injected
tests verify a/b identity plus fail-closed mismatches, but this does not establish
the missing real improper-null acceptance evidence.

Read-only candidate SHA256 identifiers:

- missingmed `mbco-d4-medsim-0.5.1.rds`:
  `b88d9e26e462f6f387ea711766511507f8c638939f18d95ddab67c640964e4e8`
- active medfit `sem-v080-frozen.rds`:
  `434101e10791012e8c527713e8d6ea91210d384094baa846191a250a05729b1e`
- active medfit `memory_exp.rds`:
  `ec778dc6503cb6ad0351b0dd8ce47b03c3e16ad0f67212512b263aa1f2acdccd`

### Follow-up review result

Claude job `8828d157-4d59-40c6-985c-7a3bcb055a68` returned **needs-attention**,
medium uncertainty. It read approved spec lines 1–258 and attribution test
bodies, and judged the fail-closed separate-refit design conforming to section
3's permitted alternative. It did not execute tests this time or independently
search fixtures. It omitted full provider/3b–3d body review, helper, mutation
harness, NEWS, public help/vignette and .STATUS; no broad approval is claimed.

- High evidence gap: no real stored improper null; confirmed and still open.
- Medium coverage gap: no tests triggering the fixed-x/factor-state guards;
  confirmed. Success-path parity is not guard-trigger coverage. No unrelated
  implementation expansion was undertaken in this fixture-search pass.
- Low speculative model-string seed mismatch: installed `mbco_sem()` appends
  `paste0(fit@model, "\n", con)`; the diagnostic helper uses
  `paste(fit@model, con, sep = "\n")`, identical for these scalar model/constraint
  strings. This is not a demonstrated mismatch. The unvalidated future
  nonempty `mb$improper` field is a dependency-contract risk; inspected medfit
  0.11.1 returns no such field. No universal optimum guarantee follows.

The section map verifies C5/3 attribution only with injected diagnostics and
proper stored refit parity. 3a's new fixed-x guard is success-path-only tested.
3b/4.7, 3c/4.8, 3d/4.9 and 4.10 were mapped by the existing note, not independently
re-read in full by Claude. No automatic retry, resume or budget expansion.
Requested/effective model sonnet / claude-sonnet-5-5, standard/medium; usage
232788 tokens, 7829 output, 10 turns, 53139 ms (API 52451 ms), $0.2234364.
No Evidence Lease; evidence-lease/cost-budget/turn-limit exhaustion all false.
Session `5c852e16-f9b9-4333-b1f3-c7249b60121b`; resume hint:
`claude --resume 5c852e16-f9b9-4333-b1f3-c7249b60121b`.
Recommended follow-up remains a real stored improper-null input plus guard
controls and full provider/spec-test body review. **T5 remains unaccepted.**
Candidate hashes above were identical before and after verification. This pass
changes only the verification note and .STATUS, not implementation or saved data.

## P1 diagnostic state guard controls — 2026-10-22

Starting head `8fbe88e`. Production code and approved spec unchanged. New test
`diagnostic state guards reject mismatches before public pooling` exercises the
real `.mm_sem_refit_diagnostics()` with injected exported-fit return state:

- Nonempty full fixed-x state, with identical null state to isolate the first guard.
- Null factor-map mismatch alone, and null fixed-x mismatch alone.
- Both target branches, matched helper success controls, and both public APIs
  under both ARIV modes. Exact branch errors are pinned: a full-state rejection
  always occurs at the first (a) diagnostic refit; null-state rejection names
  the selected a/b branch. Mode loops verify propagation, not independent math.
- A pooling sentinel cannot satisfy the expected diagnostic-refit error. Full
  and MBCO boundary summaries are injected; this is not a real improper-null fit.

Five deterministic files: label 39, provider 124, args 52, public lavaan 31,
acceptance 588: **834 passing assertions**, zero failures/errors/warnings/skips.
Existing `R_LIBS=/private/tmp/claude-501/medfit-lib2`, medfit 0.11.1. After the
final branch-message tightening, acceptance and targeted lint were rerun; the
other four files were unchanged. Both edited R files have no lints.

The existing acceptance mutation harness now accepts optional mutation names.
`full_fixed_x`, `null_factors`, `null_fixed_x` each bypass just one guard term in
memory and each produce 10 failed assertions in the new guard test, zero execution
errors. The harness requires failures in that specific test, not arbitrary errors
elsewhere. Initial bypass verification instead encountered aggregated warnings
after the missing rejection; public assertions now capture that path explicitly
and compare the actual error. No source-file mutation or saved-result rewrite.
The eleven existing acceptance and five provider mutations were not rerun here.

### Claude P1 review receipt and scope

Job `e3d5579a-906d-4942-8931-ad3259f96d93`, standard/medium, requested sonnet,
effective claude-sonnet-5-5: **approve**, static P1 scope only, medium uncertainty.
Read acceptance tests, mutation harness, helper/provider lines 215–304 and grep
excerpts from spec/plan/run. Did not execute tests/mutations (reported plan-mode
restriction), read full spec clauses 3a–3d/4.7–10, public pooling body, helper
definitions or legacy helper. No complete spec-compliance approval is claimed.

Low coverage finding: error regex did not pin a/b. Confirmed; tightened after
review and tested locally. Also hardened mutation assertions and warning/error
capture during this review cycle; final test/harness edits were not re-reviewed.
No automatic retry, resume, model chaining or budget expansion.

Clause evidence: C5/3 and 3a gain injected state-guard and exact public-error
controls; 3b/4.7 LR, 3c/4.8 completeness, 3d/4.9 df and 4.10 diagnostic/encoding
controls reran in the five files, but Claude did not independently read their
complete clause/body mapping. The pre-existing matrix remains partial, not a
substitute for independent review. P2 review checklist therefore stays open.

Usage: 216293 tokens, 6191 output, 9 turns, 45225 ms (API 44515 ms), $0.1632088.
No Evidence Lease; evidence-lease/cost-budget/turn-limit exhaustion all false.
Session `c2a5e160-3199-4d3b-8edb-67a3fe549574`; resume hint
`claude --resume c2a5e160-3199-4d3b-8edb-67a3fe549574`. Recommended next step:
complete remaining spec-body review and obtain a qualifying pre-existing input.

Frozen MBCO fixture SHA256 unchanged:
`b88d9e26e462f6f387ea711766511507f8c638939f18d95ddab67c640964e4e8`.
No installs, simulations, saved-result changes, full random-data suite, package
check, push or merge. **T5 remains unaccepted pending real-case evidence.**

## P2 clause-by-clause evidence review — 2026-10-22

Author approved explicit acceptance criteria in chat; recorded in
`tasks/plan.md` without changing the approved specification. Review baseline
`060cb3f`. No production/test changes are authorized by this P2 documentation
and review pass. The following is a source-body evidence map, not a declaration
that all gates pass. PASS means sufficient scoped evidence, FAIL demonstrated
incorrect behavior, BLOCKED missing evidence. Final review disposition follows.

Abbreviations: A=`tests/testthat/test-mbco-sem-acceptance.R`,
P=`tests/testthat/test-mbco-sem-provider.R`,
G=`tests/testthat/test-mbco-sem-args.R`,
L=`tests/testthat/test-mbco-lavaan.R`. Line anchors refer to baseline 060cb3f.
I=injected summaries/state; S=existing stored observations; R=real dependency
fits on those observations. Source trace alone is not an executed defect test.

| Clause / requirement | Actual test-body evidence | Boundary / initial disposition |
|---|---|---|
| C5/3 full failure and sample retention | A:487 target=1:3, optimizer/postfit/rows, both APIs/modes; P:189 full error | I; actual full fitter checks finite discrepancy and observed rows; no global-optimum proof. |
| C5/3 once-per-dataset notices | P:168 collects first-start/mixture; P:220 preserves starts-disagree on error; A:213,469 improper character/silent payload | I; warning types partly tested separately, aggregation tested; no real improper null. |
| C5/3 a-only, b-only, both attribution | A:309 matching diagnostics/LR/sample/error controls; A:425 both APIs/modes and one-warning/both-flag case; A:294 structured b label | I plus real refit scaffolding; warning order is not identity evidence. |
| C5/3 fallback setting/sample/LR match | A:339 numeric/binary and implicit/explicit means; A:309 rows and LR mismatch/error; A:356 state guards | S/R proper fits + I failures; real improper fallback integration BLOCKED. |
| 3a allow-list, refusals, fixed_x FALSE | G:1,12,31,49,58; L:44 NULL refusal; L:50 early public refusals | I and S/R observed/latent option parity; NULL is rejected, list() accepted. |
| 3a fallback guard isolation | A:356 matched helper controls; nonempty full fixed-x, separate null factors/fixed-x, exact a/b errors; both APIs/modes | I state on real fits; three isolated bypass mutations; final assertions require review. |
| 3b finite likelihood summaries, correct encoding | P:1,39; A:44 both branches/target=1:3/modes/APIs; adapter finite full f and branch f checks | I plus S/R parity. Null sample equivalence outside fallback relies on inspected dependency contract. |
| 3b invalid losing branch and nonfinite LR | A:44 branch=1:2, negative/Inf/NA, each dataset; P:86 stack; P:103 Inf/-Inf/NaN/NA | I; no selecting successful survivor before validation. |
| 3b absolute raw-LR tolerance / roundoff | P:103 exact -1e-7 boundary and ±1e-12; P:1 warning/zero; P:48 independent observed/latent/interior-null oracle | I + S/R; NOTE-T2 documents max reference error <=5.543e-10 and raw-LR tolerance 1e-7 before K scaling. |
| 3b dimensions / matching contracts | P:198,229 equality/shared-label dimensional oracles; P:246,259,272 variance feasibility; A:114 k mismatch | S/R and I; equality constraints add one independent dimension or refuse; no weights/likelihood-changing options delegated. |
| 3c both partial failures, all-failure, duplicate branches | P:113 good[i,], converged[i]=FALSE, all FALSE, duplicate; A:72 only_a/only_b/failed_a/failed_b/all_failed/duplicate/none, targets=1:3 | I; public refusals, not dependency enumeration implementation. |
| 3c unresolved potentially better branch (1 vs survivor 9) | P:113 and A:72 reject either missing branch regardless survivor statistic | I general refusal evidence, but no literal counterfactual failed discrepancy=1/survivor=9 control identified; sufficiency awaits review, not silently marked PASS. |
| 3c optimizer versus postfit, all-success minimum | P:113 distinct error payloads and success d_S=.5; A:72 optimizer/postfit, successful minimum; A:487 full errors | I; unusable dependency result refuses; cannot recover a likelihood dependency did not return. No claim of usable-likelihood diagnostic ledger. |
| 3c proved infeasibility | P:246,259,272 geometric affine variance/consistency controls; A:149 a==z+q | I source geometry; refuse inference rather than exclude a branch and continue. No error-string exclusion. |
| 3c unsupported union, alias, duplicate products, nested route | P:27,156 constraints/defined aliases; A:149 both APIs/modes, zero full-fit calls | I syntax; nonlinear full model refused before its nested refits can run. Not a test of dependency branch statuses. |
| 3c 64-branch limit | A:149 six/seven binary products (64/128 combinations) refused before fitting | I unsupported-route rejection at both sizes, NOT proof of an implemented 64-branch enumerator; P:272 limit=65 concerns affine work, not branch count. |
| 3d / 4.9 independent positive df | A:17 K=20,k=1 rational oracle: r4=1,D4=1,nu=76,p=F(1,76); Li=20884/361 | Independent I known answer; Li mutation; expected values do not call tested helper. |
| 3d zero ARIV / gap threshold | A:33 gap=-1,0,.5e-10 versus 2e-10 | I; zero r4/Inf nu and positive finite alternative. |
| 3d legacy versus frozen provenance | A:173 stored SEM/GLM and saved current references, legacy-own vectors; helper-legacy-mbco.R:66 | S/R; copied driver calls today's df helper, not independent historical df; frozen file unchanged. |
| 3d / 4.10 factor-two, stack/K, own/fixed | A:114 independent raw-LR rows (1,9),(9,3),stack(8,12); A:173 stored cross-check | I + S/R; scale/stack mutations, no new df API. |
| 3d / 4.10 tie, branch swaps, mixing, k | A:114 ties to a, swapped diagnostics, branch_mix/p_branch_a, k mismatch both modes | I; scalar D4 equality alone insufficient. |
| 3d numeric result indexing | A:114 ["p"], [["p"]], $p refusal | I through real result class. |
| 4.7 negative-LR planted defects | A:44 + P:103 and provider `lr` mutation | I; abs-LR mutation must fail, raw roundoff separate. |
| 4.8 completeness planted defects | A:72,149 + P:113,156 and syntax/completeness mutations | I; missing/success controls and unsupported routes mapped above; literal 1-versus-9 evidence question remains explicit. |
| 4.9 historical-df planted defects | A:17 + `li_df` mutation | I independent oracle, not legacy-driver self-consistency. |
| 4.10 encoding/diagnostic planted defects | A:114,213,309,356,425; acceptance scale/stack/tie/labels/dimensions/improper/identity/LR/state mutations | I, with S/R proper fit scaffolding; real improper input still absent. |
| Author-added real-case gate | Bounded search receipt above, no qualifying stored case | BLOCKED; injected diagnostics or more clean fits do not close it. |
| Author-approved review gate | Previous excerpt-only reviews and unreviewed assertion edits | BLOCKED until current Claude receipt establishes actual full clause/body coverage; approval label alone insufficient. |

### P2 rerun and independent-review receipt

Existing medfit 0.11.1 at `/private/tmp/claude-501/medfit-lib2` was used without
installation. Five deterministic files: labels 39, provider 124, args 52,
public lavaan 31, acceptance 588: **834 assertions**, zero failed assertions,
errors, warnings or skips. Both existing in-memory mutation scripts completed:
provider counts 15/14/3/9/34; acceptance counts
4/39/3/20/2/2/17/32/3/10/2/10/10/10 (script order). These are aggregate
failures/errors, not proof that every mutation failed its intended assertion.
Only the final three acceptance controls enforce a named failing test and no
execution errors. No production/test/harness changes were made in this pass.

Unchanged SHA-256: stored fixture
`b88d9e26e462f6f387ea711766511507f8c638939f18d95ddab67c640964e4e8`;
installed medfit `R/medfit.rdb`
`8f0a2c7e6719935753715a59a7dc86e63ef9c00a72cf633e27106e760425c217`,
`R/medfit.rdx`
`801cbbf95c240f996ea9ca696a42575e7ccc3fe68750dc6108200cdb3db93bab`.

Claude job `d2de0736-0218-4b06-9281-e228ead67d7d`, baseline `060cb3f`
plus working-tree plan/matrix: **needs-attention**, static only, medium
uncertainty. Requested sonnet, effective `claude-sonnet-5-5`, standard/medium;
24 turns, 134752 ms (API 134183), $0.7452398. Usage: input 18,
cache creation 124985, cache read 697438, output 17552 (thinking 10646),
839993 total tokens. Max/finalize turns 24/22, budget $2, timeout 240000 ms.
Evidence-lease exhaustion, cost exhaustion and turn-limit flags all false;
budget_exhausted false. Session `54b7131f-6e6a-4337-a331-81aa25dc9edd`;
resume hint `claude --resume 54b7131f-6e6a-4337-a331-81aa25dc9edd`.
No automatic follow-up was started.

Claude read the full approved spec, plan/matrix, four SEM test files, legacy
helper, both mutation harnesses, provider, infer, pooling/public source, result
class and actual `vignettes/articles/lavaan-sem.Rmd`. It only grepped
`man/mbco_d4.Rd`; omitted NOTE-T2 tolerance rationale, denominator note, frozen
fixture, installed medfit source, `.check_lavaan_spec`, todo, NEWS and .STATUS.
It did not run the diff adapter or tests. Codex read the full help and installed
`mbco_sem` source separately; that does not close independent-review omissions.
The initial overlong focus was rejected before job creation; one bounded job ran.

### Findings and disposition (no implementation)

| Finding | Disposition / evidence needed |
|---|---|
| Real improper-null fallback liveness unproven (high) | Confirmed evidence gap, not demonstrated wrong inference. P3 needs a qualifying pre-existing input and matching independent diagnostics/LRs/public warning; T5 UNACCEPTED. |
| 64/128 controls do not exercise enumeration (medium) | Confirmed. Generic products are refused before counting; affine work cap is unrelated. BLOCKED pending author ruling that refusal makes enumeration-limit testing inapplicable, or approved scope change. |
| Proved-infeasible exclusion is only refusal (medium) | Confirmed distinction. No exclusion-and-continue evidence; BLOCKED pending author interpretation or authorized implementation. |
| Mutation gates accept incidental errors / missing targeted bypasses (medium) | Confirmed harness weakness. Intended-test, zero-error evidence and table/completeness, empty-improper and n_obs bypass coverage remain open; 19 detected mutations alone do not close this gate. Historical 16-count text clarified above. |
| Literal discrepancy 1 versus survivor 9 absent (medium) | Not confirmed as stated: A:72 builds diff_ll=c(1,9); failed_a sets converged=c(FALSE,TRUE), so unresolved a=1 versus surviving b=9 is already refused across both APIs/modes/datasets. This proves refusal, not usable optimizer likelihood recovery or a global certificate. Mutation sensitivity of the completeness check remains open. |
| Post-fit policy is message-level and incompletely public (low) | Confirmed evidence/documentation gap. Dependency errors with no returned likelihood cannot be recovered by this adapter; preserving a usable returned likelihood is not demonstrated. Author interpretation and public policy clarification remain open. |
| Pool k validation / future nonempty improper payload (low) | Confirmed generic hardening risks, not a demonstrated current SEM defect: provider emits k_a=k_b=1; installed medfit lacks structured improper payload. Scope/contract decision required before changes. |

Final gate disposition: LR validity **PASS scoped** (tolerance independent-review
omission retained); df/compatibility **PASS scoped**; injected attribution/P1
guards **PASS scoped**. Completeness, stronger mutation evidence, complete
independent review and real improper-null integration **BLOCKED**. P2's bounded
audit is complete with findings/omissions recorded; its acceptance-review gate
is not satisfied. **T5 remains UNACCEPTED.** No installs, simulations, saved-result
changes, push or merge; further fixes/review require authorization.
