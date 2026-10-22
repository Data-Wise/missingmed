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

All 16 mutation controls detect defects: the original five provider controls
plus eleven acceptance controls. The two added controls force warning-order-like
identity (10 failures) and remove LR matching (2 failures); final acceptance
mutation counts are 4/39/3/20/2/2/17/32/3/10/2 in script order.

Targeted lint passes with `devtools::load_all()` before linting; without loading,
the standalone `R/infer.R` linter falsely reports the package-internal provider
as undefined. Approved spec and saved fixtures remain unchanged. No installs,
simulations, push, or merge. Local implementation does not imply T5 acceptance.
