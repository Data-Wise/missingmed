# T3 fit_args verification

Approved contract: SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md section 3a,
unchanged. Internal provider only; public lavaan wiring remains T4.

`.mm_sem_check_args()` ignores exactly estimator (ML only), std.lv, std.ov,
fixed.x, conditional.x, meanstructure, information, missing, se and test.
It reuses existing case/dot/underscore normalization; refuses duplicate aliases,
malformed lists and every unlisted option by name, including likelihood=wishart.
NULL is not a named list and is refused; public compatibility is a T4 check.
No arguments are forwarded: `.mm_sem_fit()` still forces fixed_x=FALSE.

Existing medfit 0.11.1 at /private/tmp/claude-501/medfit-lib2; no installs.
Deterministic checks: label38 + provider124 + args52 = 214 assertions,
zero failures/errors/skips/warnings; provider lint clean. Stored iris and
Holzinger data give exactly identical branch results with the combined ignored
options versus defaults. A real dependency-call capture verifies fixed_x=FALSE.
Mutation detections: LR15, completeness14, labels3, feasibility9, args34.

Reproduce with R_LIBS=/private/tmp/claude-501/medfit-lib2, devtools::load_all()
and testthat::test_file() on test-mbco-sem-label.R, test-mbco-sem-provider.R,
test-mbco-sem-args.R; run dev/check-sem-provider-mutations.R separately.
No simulations, saved-result changes, full RNG suite, public migration or merge.
Documentation search covered README, help and vignettes: current public lavaan
guidance remains accurate until T4; only internal NEWS updated now.

Claude plugin job bb4ea7df-e719-41af-89bb-5553fd7dcbf4 approved T3 only,
no findings, low uncertainty. Read spec, provider, name normalization, all three
test files, harness and NEWS; executed all focused tests and five mutations.
Only unrelated plan skipped. Requested Sonnet/effective claude-sonnet-5-5,
standard/medium: 13 reported turns, 40.937 seconds, 217520 tokens, $0.139765.
Tool reports no evidence lease, no cost exhaustion, no turn-limit exhaustion
(despite reported turns exceeding configured 12). No continuation/retry.
Manual resume: `claude --resume a66b505b-1f3c-4cb7-9594-49f3ee8a491a`.
