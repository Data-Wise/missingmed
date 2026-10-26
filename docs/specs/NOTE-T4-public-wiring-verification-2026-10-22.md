# T4 public wiring verification

Contract: SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md, unchanged.
Both infer(type="mbco") for the lavaan engine and mbco_d4(model=) now use
.mm_sem_provider(). run() still uses lavaan. Retired R/mbco_lavaan.R,
MLR internal scaling, its test and six MLR harness source files. Git retains
these sources; no saved results changed. The result scaling property remains
for compatibility, NA for fitted results. EFA syntax is explicitly refused
rather than silently losing its parser modifier.

fit_args=NULL compatibility was checked at both public entry points: it was
already invalid under the named-list contract and remains refused. list() is
accepted. Documentation distinguishes run() arguments from the stricter MBCO
allow-list and explains medfit >= 0.10.0 runtime requirements. DESCRIPTION's
floor change remains T6. README, help, FAQ, SEM article, refcard, NEWS and
contributor architecture pointers were searched and updated.

Existing library: /private/tmp/claude-501/medfit-lib2, medfit 0.11.1; no installs.
With R_LIBS pointing there, devtools::load_all() and testthat::test_file() on
test-mbco-sem-label.R, test-mbco-sem-provider.R, test-mbco-sem-args.R and
test-mbco-lavaan.R passed 39 + 124 + 52 + 31 = 246 assertions, with zero
failures, errors, warnings or skips. dev/check-sem-provider-mutations.R detected
all five mutations: LR15, completeness14, labels3, feasibility9, args34.
Changed provider/public R code lint was clean; git diff --check was clean.

Public tests use stored iris and Holzinger data, not simulated observations.
The complete-data mids wrapper initializes and restores RNG state with
withr::with_seed(1, mice::as.mids(...)); no values are imputed or generated.
Both ariv modes cover pipeline/direct/GLM parity, provider invocation, invalid
arguments, NULL, latent and defined-effect paths, aggregated warnings and a
losing-branch negative LR. The independent lavaan oracle fixes null rows in
parTable(), removes fitted est/se/start columns, reindexes free rows and uses
fixed.x=FALSE for full and null fits. Omitting these steps produced invalid
likelihood comparisons; the corrected oracle passes.

The old random-data public suite was replaced, not fully ported. T5 still owes
broader acceptance coverage, including independent df parity and reliable
branch-specific improper-null diagnostics. No full RNG suite, full CI or
vignette render was run. Roxygen regenerated four help files, with existing
unresolved IPW internal-link warnings (.ipw_weights/.ipw_weights_info).

Claude plugin adversarial job 0a3199e9-ab69-467e-8bd0-a621375d39aa approved
the scoped T4 changes, no blockers, medium uncertainty. STATIC ONLY: it reported
plan-mode restrictions and executed no checks. It read the approved spec,
infer.R, mbco_mi.R, mbco_sem.R, MbcoMIResult.R, set_md_mediation.R and the
public test. It skipped full label/provider/args tests, refcard test, mutation
harness, vignettes, generated help, NEWS and README. Its low-severity stale
CLAUDE.md legacy-provider pointer (confidence 0.8) was repaired afterward in
both contributor guides; no automatic review continuation was launched.
Requested Sonnet/effective claude-sonnet-5-5, standard/medium: 12 turns,
37.846 seconds (API 37.093), 316301 tokens, 5786 output tokens, $0.2425708.
No evidence lease or lease/cost/turn-limit exhaustion reported.
Manual resume: claude --resume de27c68f-6040-4964-8420-738e530059fd.

No simulations, dependency installs, saved-result changes, push or merge.
Unrelated docs/PLAN-research-workflow-enhancements-2026-10-20.md preserved.
