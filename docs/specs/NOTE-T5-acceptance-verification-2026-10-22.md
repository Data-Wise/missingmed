# T5 deterministic acceptance coverage — 2026-10-22

Status: partial; **T5 is not fully accepted**. Approved spec unchanged.
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
