# SPEC: MBCO refits must converge (`infer(type = "mbco")`, `mbco_d4()`)

| | |
|---|---|
| **Status** | DRAFT 2026-10-08, amended after adverse review (section 9); not implemented |
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
| C5 | Message | Two distinct messages, both prefixed by `lls_of()` with `"Fitting the MBCO models failed in imputation k: "` or `"... in the stacked data: "`. Flag false: `"the <full\|a = 0\|b = 0> <mediator\|outcome> model did not converge"` plus a hint (rescale, merge sparse levels; the data may be separated). Non-finite log-likelihood: `"the <...> model has a non-finite log-likelihood"` (no separation hint). | One message for both (mislabels a converged fit with a bad likelihood) |
| C6 | Near-separation with `converged = TRUE` | **Not refused; documented.** Measured 2026-10-08: among 400 near-separated binary fits (n = 40), 118 report `converged = TRUE` together with glm's "fitted probabilities numerically 0 or 1" warning, with finite log-likelihoods (first case: ll = -4.05, max abs coef 13.3) and data that are not separated. Refusing them would be a false refusal. glm's own warning already reaches the user unmodified (the `tryCatch` in `lls_of()` handles errors only) and stays unchanged. The contract claims validity for **converged finite fits**, not that a finite MLE exists in every case; `?mbco_d4` states that a 0/1 warning means the chi-square-type reference may be poor. | Refuse on the warning (false refusals; changes converged outcomes); add our own warning (duplicates glm's) |
| C7 | `glm.control` | Not exposed. The defaults (`maxit = 25`) stay; a user who needs more iterations is told to simplify the model. | Add `control =` to `mbco_d4()` (new API; separate spec if wanted) |

## 4. Non-goals

- Any change to a converged fit's numbers (see the converged-fits criterion for how that is evidenced).
- New arguments, new warnings on converged fits, or retrying with different starts.
- The lavaan engine (SEM spec S5/S6).

## 5. Acceptance criteria

Each must be able to fail.

- [ ] **Separated outcome refuses.** `mbco_d4()` on imputations where binary Y is completely separated by M errors with a message containing the model (`outcome`), the branch, and `imputation <k>`; verified RED on the unfixed code (it returns a p-value) and GREEN after.
- [ ] **Each branch is named.** Separation induced so that only the `b = 0` (mediator dropped) fit fails names `b = 0`; a failing `a = 0` mediator fit names `a = 0`; a failing full fit names `full`. (Planted defect: swapping the labels must fail a test.)
- [ ] **Stacked data.** A failure only in the stacked fit says `the stacked data`.
- [ ] **Non-finite log-likelihood refuses** (a stub `glm` returning `-Inf`) with the **non-finite message**, not the convergence one, and the same dataset prefix.
- [ ] **No false refusals.** The steep-but-converged case (slope 8), a converged fit that carries glm's "0 or 1" warning (seeded near-separated case; the result is returned and glm's warning still surfaces), and every existing glm MBCO test pass unchanged: 286 expectations in `filter = "mbco"` today (0 failed, 0 skipped).
- [ ] **Converged fits unchanged.** The diff only adds a check after each `glm()` call, so no converged number can move. Evidence: (a) the suite's 286 existing MBCO expectations unchanged; (b) D4, p, r4, nu equal to 1e-10 relative against values frozen from 0.7.0 on a fixed-seed fixture, both `ariv` settings (a tolerance, not `identical()`, because BLAS differs across platforms); (c) PR evidence: the same fixture run on the 0.7.0 and the fixed code on one machine compares `identical()`. The guarantee is scoped to these fixtures, not asserted for every possible converged fit.
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
| `sensitivity_mnar(type = "mbco")` has no per-rung `tryCatch` (`R/sensitivity_mnar.R:287`): an extreme delta that induces separation now aborts the whole sweep and discards the valid rungs, where it used to return an invalid p-value for that rung | Medium | **In scope: the error names the rung** (`rung i of n, delta = ...`), so the user can see which delta failed and rerun with a narrower grid. Keeping the successful rungs needs a result class that can hold a failed rung (`MDSensitivityResult`), which is a separate spec (section 10, open question) |

## 8. Boundaries

- **Always:** reproduce RED on the unfixed code before writing the fix.
- **Ask first:** exposing `glm.control`; treating warnings as failures.
- **Never:** compute a p-value from a non-converged fit; change a converged fit's numbers.

## 9. Adverse review (2026-10-08)

Codex adversarial review of this spec, plus a probe of its high finding.

| # | Finding | Outcome |
|---|---|---|
| 1 | High: `converged = TRUE` does not rule out separation (C6) | Partly accepted. Probe: 118/400 near-separated fits converge with finite likelihoods and glm's 0/1 warning, so refusing would be a false refusal. C6 rewritten: not refused, claim narrowed to converged finite fits, caveat documented, regression test added. |
| 2 | Medium: one failed rung discards the whole sensitivity sweep | Partly accepted. The error now names the rung and delta (in scope). Keeping successful rungs changes `MDSensitivityResult`; moved to an open question. |
| 3 | Medium: `identical()` is not what the WIP test enforces, and the guarantee is broader than the fixtures | Accepted. Criterion rewritten: 1e-10 against frozen 0.7.0 values plus an `identical()` old-vs-new comparison as PR evidence, scoped to the fixtures. |
| 4 | Low: non-finite likelihood mislabeled as non-convergence | Accepted. Two distinct messages (C5). |

## 10. Open question for the author

`sensitivity_mnar(type = "mbco")`: should a failed rung be **kept as a failed rung** (the sweep returns the other rungs and flags this one) instead of aborting? Recommendation: yes, but as its own spec, since it changes `MDSensitivityResult`. This spec only makes the abort identify the rung.
