# D4 post-fit evidence — local wrap-up checkpoint

Local checkpoints: medfit `f31e12e`; rforge website source `7c4ec3e`.
Rforge validation: 920 Python tests passed, four skipped; 46/47 wrapper checks
passed, with only eight pre-existing generated-reference drift pages failing.
Offline strict content preview passed; full social-card rendering and deployment
remain unverified. No push or merge.

## Scope and implementation

Dependency worktree `/private/tmp/medfit-d1.3jrA2K/medfit`, branch
`codex/medfit-d4-post-fit-evidence`, based on D3 `cba4c1a` (D1 pinned
`8d7d6c14e038b8f41d9e1bbe37a4e74bf54b404f`). No missingmed production
adapter change and no D5 integration or T5 acceptance.

The pipeline validates defined-parameter values/gradients and other post-fit
metadata before covariance, then snapshots the accepted optimizer result and
normalized sample/model/domain/settings. Only an escaping `.sem_vcov` error
creates `medfit_sem_covariance_error`: schema 1, covariance stage, partial
likelihood/optimizer/context, outcome and diagnostics, no vcov/defined output.
Public fitting/conversion still throws. Internal branch/null handlers validate
the payload, preserve notices and completeness, and additionally check null
sample/domain/model/dimensions before LR consumption. Existing singular-info
warning/NA covariance behavior is retained; finite f does not clear identification
or boundary warnings or establish globality.

## Deterministic evidence

New `tests/testthat/test-sem-post-fit.R` initially failed: covariance errors had
no typed partial/objective and retained raw pre-deletion context. The expanded
tests additionally caught dropped identification notices and normalized union
context field-order mismatch; both repaired before review.

654 dependency assertions (=570 prior +84 D4) and 816 consumer assertions pass,
zero failures/errors/unexpected warnings, using source-loaded existing libraries,
single starts and a `.sem_perturbed_starts` trap. Consumer files are encoding,
provider and acceptance. Dependency runner evaluates only allowlisted stored-data
legacy bodies plus expr/outcomes/literal-certificates/branch-map/post-fit files.
The post-review harness formatting was retested separately. Generated Rd inspected.
Changed-file lint has one pre-existing `assignment_linter` finding on the unchanged
`outcomes[[i + 1L]] <<-` statement in sem-mbco.R (base line 203); no new lints.
Fixture Git blob remains `13b372d9fcf182dbbeae5b426621cedc2a9dd276`.

No full R CMD check, full stochastic suite, vignette execution, installs,
simulations, saved-result changes, push or merge. Injected covariance exceptions
are not naturally observed failures and do not satisfy the real-case gate.

## Approved-clause tracing and independent review boundary

Owner reread approved proposal D4 lines 131–159 and original spec C5, 3c, 3d,
items 8–10. D4 test bodies cover typed full-fit public consumption/refusal,
identical objective/theta and post-deletion context; both null orderings with
branch notices; model/definition/optimizer/nonfinite gates; singular-info NA
behavior and retained identification warning; both nested child orderings;
malformed schema and incompatible null dimensions. Existing bounded consumer
regressions exercise historical pooling/encoding without altering them.

Claude job `cfded747-7556-4879-ad42-d271b18498ec` approved its scoped static review,
with one low finding and medium uncertainty. It read the D4 proposal and diffs,
but explicitly omitted original C5/3c/3d/4.8–10, new test lines 1–99, full outcome/
require/condition/vcov helpers, LR/p consumption, nonwinning notice path,
CLAUDE.md and fit_sem.Rd diff. **No full approved-spec closure claim.** No tests
run by Claude. Raw receipt: `D4-claude-review-2026-10-22.json`, preserving coverage,
all omissions, usage, model and budget fields (Sonnet 5.5 medium; 11 turns;
235477 tokens; $0.2402473; 76198ms; no budget/turn exhaustion).

Low finding: a union root retains the first covariance-failing child's post_fit,
which need not be its minimum-f winner. Child IDs preserve exact attribution and
the LR is unchanged. Documented this conservative root semantics after review;
an explicit nonwinning-failure attribution assertion remains open. Documentation
and formatting follow-up is not independently re-reviewed. No automatic rerun.

## Wrap-up and next bounded step

D4 implementation is a local, tested checkpoint, not independently closed.
Next: focused read-only closure of omitted original clauses/full test bodies and
the union attribution concern before D5. D5 public adapter integration, a
qualifying pre-existing real case and final T5 acceptance remain open.
Planning/status/agent guidance and website source are synchronized; deployment
is not authorized. The rforge website change is isolated in
`/private/tmp/rforge-evidence-docs.m9eD08/rforge` on `codex/d4-evidence-docs`.
Its strict offline content preview was built and output text/size/section count
inspected; social cards omitted in scratch config only, no visual inspection.
Full configured build blocked by existing imaging runtime/font-network needs;
920 Python tests pass/4 skip, version sync passes, pre-existing generated-reference
drift recorded. No site deployment. AGENTS.md is locally updated but gitignored
by the repository's existing policy; CLAUDE.md carries the tracked guidance.
