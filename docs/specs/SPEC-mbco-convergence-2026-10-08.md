# SPEC: MBCO refits must converge (`infer(type = "mbco")`, `mbco_d4()`)

| | |
|---|---|
| **Status** | DRAFT 2026-10-08; not implemented |
| **Origin** | Codex adversarial review, 2026-10-08 (finding: "MBCO accepts log-likelihoods from non-converged fits", `R/mbco_mi.R:82-83`); reproduced below |
| **Target** | 0.7.1 (bug fix; no API change) |
| **Affects** | `R/mbco_mi.R` (`.mm_ll_med()`), tests, `NEWS.md` |
| **Related** | [SPEC-sem-mbco-2026-10-08.md](SPEC-sem-mbco-2026-10-08.md) S5 (the lavaan half of the same contract) |

## 1. Objective

An MBCO statistic is a likelihood-ratio. A log-likelihood from a `glm()` fit that
did not converge is the value at an arbitrary last iterate, not a maximum, so
`2 (ll_full - ll_null)` is not an LRT and its p-value is not valid. Today
`infer(type = "mbco")` and `mbco_d4()` return such a p-value with no warning.
After this change they **refuse**, naming the dataset, the branch and the model.

## 2. Evidence (reproduced 2026-10-08 on `dev` 8bee2bc)

| Case | glm | What `.mm_ll_med()` does today |
|---|---|---|
| Binary Y completely separated by M (n = 120) | `converged = FALSE`, 25 iterations, warnings "did not converge" and "fitted probabilities numerically 0 or 1", ll = -5.1e-08 | returns -173.76 (sum with the mediator model) and `infer()` goes on to a p-value |
| `maxit = 2` on a steep binomial fit | `converged = FALSE`, ll = -23.97 | accepted |
| Steep but not separated (slope 8) | `converged = TRUE`, 9 iterations | correct |

Call sites: `.mm_d4_mbco()` (used by `infer()` and `mbco_d4()`) and
`.mm_mbco_T()` (complete-data helper), all through `.mm_ll_med()`. The existing
`tryCatch` in `.mm_d4_mbco()` (`lls_of()`) catches **errors only**, so a
non-converged fit never reaches it.

## 3. Decisions

| # | Question | Decision | Alternative |
|---|---|---|---|
| C1 | Refuse or warn? | **Refuse.** A statistic from a non-maximized likelihood is not an LRT; the SEM spec (S5) and the repo rule "never compute a p-value from an unconverged null fit" already say refuse. | Warn and proceed (returns an invalid p-value) |
| C2 | What counts as failure? | `fit$converged` is not `TRUE`, **or** the log-likelihood is not finite. | Any glm warning (would refuse the benign "fitted probabilities 0 or 1" on a converged fit) |
| C3 | Which fits? | Every refit: the full and the two null fits, for both the mediator and the outcome model, in every imputation and in the stacked data. | Only the null fits (the full fit can fail too) |
| C4 | Where is it checked? | In `.mm_ll_med()`, which knows the branch and the model, so every caller is covered and the glm provider of the SEM spec's T1 carries the check with it. The existing `lls_of()` wrapper adds the dataset. | In `.mm_d4_mbco()` only (misses `.mm_mbco_T()`) |
| C5 | Message | `"the <full\|a = 0\|b = 0> <mediator\|outcome> model did not converge"`, prefixed by `lls_of()` with `"Fitting the MBCO models failed in imputation k: "` or `"... in the stacked data: "`, plus a hint (rescale, merge sparse levels, or the data may be separated). | A classed condition only (the wrapper re-throws and loses the class) |
| C6 | Quasi-separation with `converged = TRUE` | **Out of scope**, unchanged. glm reports convergence and the likelihood is a valid maximum on the boundary; the "0 or 1" warning stays a warning. | Treat the warning as failure (changes converged fits; breaks the bit-identical guarantee) |
| C7 | `glm.control` | Not exposed. The defaults (`maxit = 25`) stay; a user who needs more iterations is told to simplify the model. | Add `control =` to `mbco_d4()` (new API; separate spec if wanted) |

## 4. Non-goals

- Any change to a converged fit's numbers: **bit-identical** to 0.7.0 on every test that converges.
- New arguments, new warnings on converged fits, or retrying with different starts.
- The lavaan engine (SEM spec S5/S6).

## 5. Acceptance criteria

Each must be able to fail.

- [ ] **Separated outcome refuses.** `mbco_d4()` on imputations where binary Y is completely separated by M errors with a message containing the model (`outcome`), the branch, and `imputation <k>`; verified RED on the unfixed code (it returns a p-value) and GREEN after.
- [ ] **Each branch is named.** Separation induced so that only the `b = 0` (mediator dropped) fit fails names `b = 0`; a failing `a = 0` mediator fit names `a = 0`; a failing full fit names `full`. (Planted defect: swapping the labels must fail a test.)
- [ ] **Stacked data.** A failure only in the stacked fit says `the stacked data`.
- [ ] **Non-finite log-likelihood refuses** (a stub `glm` returning `-Inf`), same message shape.
- [ ] **No false refusals.** The steep-but-converged case (slope 8) and every existing glm MBCO test pass unchanged: 286 expectations in `filter = "mbco"` today (0 failed, 0 skipped).
- [ ] **Bit-identical on converged fits.** `identical()` p, D4, r4, nu against values frozen from 0.7.0 on a fixed-seed `mice` object, under both `ariv` settings.
- [ ] **Both entry points.** `infer(type = "mbco")` and `mbco_d4()` both refuse; `sensitivity_mnar(type = "mbco")` surfaces the same error (it calls `infer()` per rung with no `tryCatch`, `R/sensitivity_mnar.R:287`, so the sweep aborts).
- [ ] `R CMD check --as-cran` 0/0/0 (one expected pre-CRAN note), suite green with strictly more tests; `NEWS.md` bug-fix entry.

## 6. Implementation outline

| Task | Scope | Size |
|---|---|---|
| T1 | RED tests: separated outcome through `mbco_d4()`, run on the unfixed code and quote the failure | S |
| T2 | `.mm_ll_med()`: keep each `glm` fit, refuse on `!isTRUE(converged)` or a non-finite `logLik`, with branch and model in the message | S |
| T3 | Remaining tests: branch naming, stacked, non-finite, no-false-refusal, bit-identical freeze, `infer()`/`sensitivity_mnar()` entry points | S |
| T4 | NEWS, suite, `R CMD check`; PR to `dev` with the RED and GREEN transcripts | S |

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| A real analysis that worked "by accident" with one non-converged imputation now errors | Medium | Intended: its p-value was invalid. The message says which imputation and branch, and suggests rescaling or merging sparse levels |
| m = 20 with a rare binary outcome refuses on one imputation | Medium | Same message; C7 leaves a `control =` argument for a separate spec if users hit it |
| Message text changes break a downstream string match | Low | The `Fitting the MBCO models failed` prefix is unchanged; dependents' use of MBCO error text has not been checked, so T4 greps the mediationverse repos read-only before the PR |
| `sensitivity_mnar(type = "mbco")` has no per-rung `tryCatch` (`R/sensitivity_mnar.R:287`): an extreme delta that induces separation now aborts the whole sweep, where it used to return an invalid p-value for that rung | Medium | Intended for the same reason; the message does not name the rung, so T3 adds a test that it surfaces and T4 decides whether to prefix the rung index (small, in scope) |

## 8. Boundaries

- **Always:** reproduce RED on the unfixed code before writing the fix.
- **Ask first:** exposing `glm.control`; treating warnings as failures.
- **Never:** compute a p-value from a non-converged fit; change a converged fit's numbers.
