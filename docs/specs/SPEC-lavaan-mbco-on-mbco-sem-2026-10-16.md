# SPEC: lavaan MBCO on medfit's `mbco_sem()` (replaces the lavaan provider)

| | |
|---|---|
| **Status** | APPROVED 2026-10-16 (author: all four section 6 rulings as recommended); revised with an Opus research pass (section 7). Implementing on `feature/lavaan-mbco-medfit`, T1 first. |
| **Date** | 2026-10-16; acceptance addendum 2026-10-22 |
| **Supersedes** | `NOTE-lavaan-mbco-delegation-2026-10-16.md` (which recommended not delegating; the author reversed it the same day and chose **replace**, not opt-in) |
| **Affects** | `R/mbco_lavaan.R` (replaced), `R/infer.R`, `R/mbco_mi.R`, `DESCRIPTION`, 5 test files, `dev/sim-sem-mbco-mlr-*.R`, vignettes, NEWS |

## 1. Parity evidence (run 2026-10-16, medfit 0.10.0 from `origin/main` in a scratch library, lavaan 0.7.3)

`mbco_sem()$tests$diff_ll` against `2 * (ll_full - ll_null)` from missingmed's lavaan provider construction:

| Model | a branch | b branch | max abs difference |
|---|---|---|---|
| observed, n = 300 | 43.08153 | 30.58981 | 2.4e-13 |
| latent mediator (3 indicators), n = 400 | 50.37483 | 31.7686 | 6.5e-12 |
| interior null `b = 0`, n = 300 (branches disagree) | 69.39514 | 0.0808688 | 3.6e-13 |

These fixtures establish agreement for their inspected models and dependency versions. They do not
certify every supported model or unresolved branch. D4 pooling uses only differences of log-likelihoods;
retaining recorded calibration requires matching likelihood, branch, dimension and failure contracts,
including the gates below. No new calibration or simulation is authorized by this addendum. A provider is
`full = 0`, `a = -diff_a / 2`, `b = -diff_b / 2`, `k_a = k_b = 1`.

## 2. What the replacement costs (found while scoping; each needs a ruling)

| # | Today (lavaan provider) | With `mbco_sem()` | Proposed ruling |
|---|---|---|---|
| C1 | a and b rows found as `M ~ X`, `Y ~ M` in any lavaan syntax | `mbco_sem()` needs **labeled** paths (unlabeled gives "not a labeled regression path"). medfit exports only `SEMFit`, `fit_sem`, `mbco_sem`; its parser `.sem_parse` is internal, so it cannot be used | Find and validate the two rows with `lavaan::lavParseModelString(as.data.frame. = TRUE)` (handles `;`, continued lines, comments), then rewrite **only that one term**; reuse an existing label. A line-based regex was tried and broke on `M ~ X; Y ~ M + X` and silently corrupted `Y ~ M +\n X`: do not use one. Longer term: a medfit change so `mbco_sem()` accepts `"M~X"` path specs |
| C2 | `fit_args` go to `lavaan::sem()` and reach the null refits | `fit_sem()` takes `information`, `n_starts`, `control`, `meanstructure`, `fixed_x`; the rest of lavaan's options do not exist there | **Strict allow-list, every other option refused by name** (section 3a). Verified: `auto.cov.y = FALSE` moves a statistic by 4.45 and `orthogonal = TRUE` by 0.06, silently, so an unlisted option is never ignored |
| C3 | `:=` defined parameters and label equalities are supported | medfit supports labels and `==` constraints; `:=` rows must be checked | Port the two tests (`:=`, equality) as parity oracles; refuse what medfit rejects |
| C4 | MLR scaled-difference code (`.mm_lav_cd()`, `scaling`, `internal_mlr`) kept for a gate harness | none | **Delete** it, the `dev/sim-sem-mbco-mlr-*.R` harness and `test-mbco-mlr.R`; the failed gate stays on record in SPEC-sem-mbco section 12 and PR #84 |
| C5 | lavaan non-convergence and `post.check` (improper solution) messages | `fit_sem()` stops on non-convergence (no `@converged = FALSE`); `diagnostics$improper` for the full fit, warnings for the refits | Catch the errors and re-raise the existing messages; keep "warns once, naming the datasets" (section 3) |
| C6 | `lavaan (>= 0.7-3)` in Imports for MBCO | `medfit (>= 0.10.0)` hard Import; lavaan still needed for `run()` | `DESCRIPTION`: raise the medfit floor. **CRAN is blocked until medfit 0.10.0 is on CRAN** (CRAN has 0.3.2; its own `mbco_sem()` arrives with it). No `Remotes:` unless needed for r-universe |
| C7 | `run()` fits with `lavaan::sem()`; MBCO fits with the same | `run()` still lavaan; MBCO now fits with `fit_sem()` | Same likelihood on the supported option set (section 1). Document that MBCO no longer uses lavaan's optimizer, and keep a parity test as the guard |
| C8 | `run()` accepts all lavaan syntax | `fit_sem()` refuses (verified): `c(a)*` and `label('a')*` modifiers, multi-lhs `M + M2 ~ X`, `NA*` loadings, `<~`, `|`, `efa()`, two modifiers on one term (an unlabeled tested path that already has `start()` or a bound cannot take an injected label), non-numeric columns | **A second breaking change** for `infer(type = "mbco")`: each construct refused with an error naming it. A 2-level factor is coerced to 0/1 (matches lavaan exactly, 15.77536 / 46.85104); a factor with more levels is refused |

## 3. Design

- New `R/mbco_sem.R`: `.mm_sem_provider(model, treatment, mediator, outcome, fit_args)` returns
  `function(d)` giving `c(full = 0, a = -diff_a / 2, b = -diff_b / 2, k_a = 1, k_b = 1)` with
  `attr(, "improper")`. Preserve D4 arithmetic and ARIV/df semantics; any validation or
  completeness plumbing must satisfy sections 3b–3d. Per dataset (design sketch, not implemented):

```r
fit <- withCallingHandlers(fit_sem(lab_model, d, fixed_x = FALSE), warning = collect)
stopifnot(fit@n_obs == nrow(d))               # fit_sem drops incomplete rows with only a message
mb  <- withCallingHandlers(mbco_sem(fit, la, lb), warning = collect)
dl  <- mb$tests$diff_ll                       # rows a, b in path order
# Validate each finite branch difference and completeness before encoding; see 3b–3c.
# The earlier absolute -1e-6 rule is provisional, not a global-optimality certificate.
```

- Equivalent without `mbco_sem()`: `fit_sem(paste0(model, "\nlab == 0"))` with `2 * (logLik diff)` gives
  identical numbers and per-fit diagnostics, but would have to copy `mbco_sem()`'s `meanstructure` and
  `fixed_x` handling. Prefer `mbco_sem()`.
- `.mm_sem_label_model()` per C1; refuses fixed paths (`M ~ 0.5*X`), duplicated rows, multi-group, and
  the C8 constructs.
- Convergence: `fit_sem()` never returns `@converged = FALSE`; it stops with "no start converged (5
  tried)". `mbco_sem()` wraps a failed refit as "the refit with `a == 0` failed ...". Catch both and
  re-raise as "the full / a = 0 / b = 0 model did not converge" (the existing messages); there is no
  `@converged` to map and no lavaan `iter.max` hint to give.
- Improper: `fit@diagnostics$improper` covers the full fit. The refits return no diagnostics, only
  warnings starting "improper solution:"; tag them by order (the a refit runs before b). Reword the
  "lavaan's post.check failed" text at `R/mbco_mi.R:222`.
- Warnings: the lavaan provider wraps every fit in `suppressWarnings`. The new one **collects** the
  boundary ("mixture of chi-squares"), "first start was not accepted" and "starts disagree" warnings per
  dataset and re-raises **once**, naming the datasets, as `.mm_warn_improper()` does. For `a > 0` the old
  provider returned 60.72 silently.
- `R/mbco_lavaan.R`, the MLR hooks in `.mm_d4_pool()` (lines ~360-392) and `test-mbco-mlr.R` are removed.

### 3a. The `fit_args` allow-list (`.mm_sem_check_args()`)

| Treatment | Options |
|---|---|
| **Ignore** (statistic unchanged in every case tested, observed and latent, with and without covariates) | `estimator = "ML"`, `std.lv`, `std.ov`, `fixed.x`, `conditional.x`, `meanstructure`, `information`, `missing` (imputed data are complete), `se`, `test` |
| **Always pass `fixed_x = FALSE`** to `fit_sem()`; never map `fixed.x` | All 12 combinations of lavaan `fixed.x` x medfit `fixed_x` x {none, covariate, latent} gave the same statistic, and `fixed_x = TRUE` errors when the syntax writes a (co)variance of a fixed variable |
| **Refuse, naming the option** | any `auto.*` (including `auto.var`, `auto.fix.first`, untested), `orthogonal*`, `int.*.free`, `control` (lavaan's `iter.max` is not nloptr's `maxeval`), `group`, `ordered`, `sampling.weights`, any non-ML `estimator`, and **anything not listed above** |
| **Refuse (approved section 6, Q4)** | `likelihood = "wishart"` |

### 3b. Per-branch likelihood ordering (acceptance requirement, 2026-10-22)

For each imputation and the stacked dataset, validate the full fit and **both** null
fits before choosing a winner, encoding pseudo-log-likelihoods, or pooling:

- All likelihood/difference summaries must be finite; constraint dimensions must be
  positive integers and satisfy the existing cross-imputation dimension checks.
  Compare matching rows, model, likelihood convention, variance domain and weights.
- A null log-likelihood exceeding the full fit beyond numerical tolerance means
  the nested-fit comparison is unresolved. Refuse inference and name the dataset
  and branch. Do not turn a materially negative LR into zero, p=1 or a valid null
  result. Include the losing branch used for diagnostics in this check.
- State the tolerance in raw LR units, before division by K. The earlier absolute
  1e-6 threshold is provisional: document/justify the chosen absolute/relative
  tolerance against deterministic references before T2 is accepted. Define and
  report the separate treatment of roundoff-sized negatives; do not hide a
  material violation behind ARIV truncation or a large relative scale.
- Nonnegative LR is a necessary nesting invariant, not a proof of global
  optimality. Avoid the former error wording claiming the failure proves that
  a particular fit is not global; it can also indicate a model/sample mismatch.

Evidence boundary: at inspected missingmed commit `7a6bd547b4e9445a8fbb2dcde7f85cb55f092bd7`,
an injected provider `c(full=0, a=nrow(d), b=-nrow(d), k_a=1, k_b=1)` gives
D4=-2 and p=1 for two one-row placeholder datasets under both ARIV modes. This was
an isolated function check with a private result-constructor stand-in, not a real
fit or executed public S7 result. It demonstrates the missing seam invariant,
not corruption or prevalence in saved analyses.

### 3c. Branch completeness through the dependency boundary

A successful winning branch does not establish that all required branches were
resolved. Preserve per-branch outcomes through the full fit, each refit, provider
and public inference boundary. Distinguish proved infeasibility, unresolved
optimization, post-fit covariance/diagnostic failure, and an accepted likelihood.
Keep branch enumeration completeness separate from optimality within a branch.

At medfit dev `bc1e2f37179aba92b4e2a99ed40d9c6ae74995e5` and v0.12.0,
`.sem_fit_branches()` can discard one error and return the surviving fit without
its failure ledger. `fit_sem()`/`.sem_as_semfit()` do not restore that information.
`mbco_sem()` propagates an escaping refit error, but cannot detect a generic
zero-product subbranch error already swallowed in its input or refit. This is
verified control flow, not an observed wrong optimum on real data. The current
missingmed SEM path still uses its lavaan provider; T1 alone does not implement
this migration or establish an existing medfit-inherited defect in missingmed.

T2 must refuse an unresolved required union optimum or expose an explicit status
that prevents a valid inferential result. A best-surviving fit may remain available
as an explicitly incomplete diagnostic. Exclude a branch only with a reasoned
infeasibility determination, never from an error string alone. Preserve any
usable likelihood when only covariance diagnostics fail and make the inferential
policy explicit. If the selected medfit version cannot report completeness for a
generic zero-product input/refit, refuse that unsupported route rather than
inferring completeness from convergence or lack of warnings. Do not replace
ordinary separate a=0/b=0 null fits with a singular product equality.

Required controls include both partial-failure orderings, an unresolved potentially
better branch (counterfactual discrepancy 1 versus survivor 9), optimizer versus
post-fit errors, all-success minimum, all-failure, proved-infeasible exclusion,
duplicate branches, and the 64-branch limit. Test status propagation into public
objects/consumers and nested generic-product input/refit routes, not just direct
exceptions. These controls specify future implementation acceptance; they were
not executed as package integration tests in the proposal audit.

### 3d. Historical df and output compatibility

The current `.mm_d4_from_stats()` implements Chan–Meng eq. 2.15 only:
`nu = k * (K - 1) * (1 + 1/r4)^2`, with positive ARIV truncation and the documented
near-zero-gap tolerance. `ariv="own"` changes branch selection; it does **not**
select Li denominator df. Applied missingmed fixed/Chan–Meng inference, the
Missing Effect frozen medsim own/Li raw outputs, and later Chan–Meng
re-referencing are three distinct provenance contracts. Do not change frozen
outputs or add a df API as part of this migration.

`tests/testthat/helper-legacy-mbco.R:66` delegates to the **current** D4 helper.
Same-session agreement with that copied driver verifies branch arithmetic under
the current helper, not independent reproduction of historical nu/p. Retain the
existing fixture cross-check, state its reference provenance, and add independent
known-answer df assertions that do not call the helper under test to generate the
expected reference. Include K=20, k=1 with positive ARIV and a separately pinned
Li/Chan–Meng comparison from existing evidence; K=3, k=1 alone is insufficient
because the two implemented references can coincide there. Check zero ARIV gives
infinite df and explicitly test the rounding-gap threshold on both sides.

Preserve the existing own/fixed branch rules, stacked division by K, factor-of-two
encoding, tie-to-a policy, `branch_mix`, `p_branch_a`, and dimension mismatch
refusals. Swapping a/b can leave D4/p invariant when k matches, so compare labeled
branch diagnostics too. Preserve numeric-like MbcoMIResult indexing with `["p"]`
and `[["p"]]`; `$p` is not its API. Pin the executed dependency version/commit in
parity receipts; neither DESCRIPTION alone nor an installed package name proves
which implementation was exercised.

## 4. Tests (each can fail)

1. **Parity oracle** (`skip_if_not_installed("medfit", "0.10.0")`): the three models in section 1,
   `diff_ll` vs the 0* lavaan oracle to **1e-7** (an exogenous-latent-covariate model gave 1.3e-9, so the 1e-9 first drafted would fail). Planted defects, each must turn it red: swap labels `a`/`b`; pass `auto.cov.y = FALSE` through; drop the negative-statistic guard on a planted non-global optimum.
2. Port from `test-mbco-lavaan.R` the 30 existing cases that still apply; each keeps its
   assertion, only the fitter changes. The `:=`, equality, fixed-path and refusal cases port as-is.
3. `mbco_d4(model = )` equals `infer(type = "mbco")` on the same imputations (existing test).
4. New: C1 label injection on unlabeled, labeled, covariate, `;`-separated and continued-line
   syntax (the two cases that broke the regex prototype are required cases); refusal messages for C2
   and C8; `fit@n_obs == nrow(d)` assert; boundary warning raised once; a 2-level factor accepted, a
   3-level factor refused.
5. Calibration is not re-run. Section 1 supplies scoped historical parity evidence, not
   universal equivalence. Keep the glm vs lavaan agreement test
   (`test-mbco-lavaan.R:25`) and the signed/branch diagnostics under matching contracts.
6. For a later implementation PR, record `make ci` counts plus the parity table. This
   documentation-only update runs no package suite, data generators or simulations.
7. **Negative-LR defects:** test each branch in each imputation and the stack,
   including an invalid losing branch; both ARIV modes must refuse material
   violations. Removing the guard or silently flooring a material negative must
   fail the checks. Cover non-finite summaries and the stated roundoff policy.
8. **Completeness defects:** section 3c controls must verify both public propagation
   and immediate/nested refit failures. Returning a survivor with complete status
   must fail; a successful minimum in all-success controls must remain available.
9. **Historical-df defects:** independent expected values per 3d must reject a
   planted Li-for-Chan–Meng substitution. A legacy-driver test calling the current
   helper cannot serve as the independent df oracle.
10. **Encoding/diagnostic defects:** test factor-of-two, stack/K scaling, own/fixed
    statistics, tie policy, branch-label swaps, mixed imputations and k mismatch.
    Only pre-existing stored inputs or injected summaries are used under the
    present no-simulation restriction.

## 5. Tasks

| T | Task | Size |
|---|---|---|
| T1 | `.mm_sem_label_model()` via `lavParseModelString()` + tests, incl. the two regex-breaking cases (C1, C8) | M |
| T2 | `.mm_sem_provider()`, per-branch LR/completeness gates, parity and planted defects (C5, sections 1, 3b–3c) | M |
| T3 | `.mm_sem_check_args()` strict allow-list, section 3a (C2, C3) | S |
| T4 | Wire `infer()` and `mbco_d4(model = )`; remove lavaan provider, MLR code and harness (C4) | M |
| T5 | Port remaining cases; add independent df, completeness, LR and diagnostic controls (3b–3d, 4.7–10) | M |
| T6 | `DESCRIPTION` floor, NEWS (Breaking changes: C2, C4, C6), vignette `lavaan-sem` | S |
| T7 | `make ci`, PR into `dev` | S |

## 6. Questions for the author

1. **C2/C8 narrowing**: accept the strict allow-list and the narrower syntax as breaking changes for
   `infer(type = "mbco")` and `mbco_d4(model = , fit_args = )` only? Recommended: accept.
2. **C6 timing**: merge to `dev` now (r-universe has medfit 0.10.0; CRAN is already blocked on RMediation
   1.7.1), or hold until medfit 0.10.0 is on CRAN? Recommended: merge to `dev` now.
3. **C4**: delete the MLR internals and harness? Recommended: delete (the gate failed; PR #84 has it).
4. **`likelihood = "wishart"`**: ignore it (the statistic stays the `logl` difference, as today: lavaan's
   own LRT is (N-1)/N smaller, 50.534 vs 50.737 in the probe) or refuse it (honest, but breaks anyone
   passing it)? Recommended: refuse, so the test is never silently not the one asked for.

## 7. Research basis (Opus pass, 2026-10-16; scripts in the session scratchpad, not committed)

Pooled 20 imputations (n = 300 each, latent mediator): lavaan provider and medfit provider give the same
D4 = 8.171366, p = 0.006403631. Per-feature `diff_ll` agreement with the lavaan provider (max abs):
`:=` 4.5e-13; shared label 1.9e-11; explicit `==` 7.2e-10; covariates 1.7e-12; parallel mediator 8.7e-10;
latent residual covariance 1.8e-10; latent mediator / + latent outcome 6.9e-10 / 1.4e-10; exogenous latent
covariate 1.3e-9; two outcomes 2.0e-11; skewed data 3.8e-13 / 1.0e-12; interior null 2.1e-13; stacked
20 x 300 3.9e-10. Runtime is lower with medfit (20 imputations: 0.33 s vs 0.83 s observed, 0.52 s vs
1.08 s latent). Reproducible: `fit_sem` seeds perturbed starts from a hash of the model and restores the
caller's RNG. **Not verified**: lavaan's `post.check` also tests the observed residual covariance for
positive definiteness, which medfit may miss (Heywood cases matched); the untested `auto.var`,
`auto.fix.first`, `int.ov.free`. The report is a subagent's; the three parity tables in section 1 were run
by me, the rest is not independently reproduced.

## 8. Acceptance addendum provenance (2026-10-22)

Requested by the author after the adversarial cross-repository proposal audit,
`Missing Effect/docs/reviews/PROPOSAL-branching-medsim-medfit-pmed-2026-10-22.md`
(F2, F4, F5). The original replacement decision and all four approved rulings
remain in force. This addendum updates the specification only: T2–T7 are not
implemented, no simulation or calibration was rerun, and saved results remain
untouched. Historical version/CRAN/status statements above retain their original
evidence dates; recheck current release availability before a future integration.

Pinned evidence: [missingmed pooling](https://github.com/Data-Wise/missingmed/blob/7a6bd547b4e9445a8fbb2dcde7f85cb55f092bd7/R/mbco_mi.R),
[legacy driver](https://github.com/Data-Wise/missingmed/blob/7a6bd547b4e9445a8fbb2dcde7f85cb55f092bd7/tests/testthat/helper-legacy-mbco.R#L66),
[medfit generic branch enumeration](https://github.com/Data-Wise/medfit/blob/bc1e2f37179aba92b4e2a99ed40d9c6ae74995e5/R/sem-fit.R#L215-L272),
and [public fit conversion](https://github.com/Data-Wise/medfit/blob/bc1e2f37179aba92b4e2a99ed40d9c6ae74995e5/R/fit-sem.R#L122-L145).

### Filed tracking issues

- [missingmed #101](https://github.com/Data-Wise/missingmed/issues/101): this migration's LR, completeness and historical-df acceptance gates.
- [medfit #295](https://github.com/Data-Wise/medfit/issues/295): dependency branch-completeness reporting.
- [medsim #64](https://github.com/Data-Wise/medsim/issues/64): Pmed target and inference labeling.
- [medsim #65](https://github.com/Data-Wise/medsim/issues/65): matched ARIV/p columns and branch flags.
- [pmed #68](https://github.com/Data-Wise/pmed/issues/68): unresolved profiles and endpoint recovery.
- [Missing Effect #36](https://github.com/Data-Wise/missing-effect/issues/36): companion/frozen-run provenance.
