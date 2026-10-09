# SPEC: `sensitivity_mnar(on_error =)`, keep the rungs that worked

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | DRAFT for author review. No code written. |
| **Plan / grill** | [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md) item A; [GRILL-open-items-2026-10-09.md](GRILL-open-items-2026-10-09.md) Q1 = (c) |
| **Target** | 0.9.0 (new argument and a new result property; default behavior unchanged) |
| **Size** | S |

## 1. Problem

`sensitivity_mnar()` refits and infers at every rung of a delta grid. A refit that
fails (a non-converged `glm()` since 0.8.0, a non-converged or improper lavaan fit)
raises an error, and the loop in `R/sensitivity_mnar.R:275-300` has no way to keep
the rungs already computed. A failure on rung 18 of 20 discards 17 good rungs, and each
rung re-imputes and refits. Only the MBCO path wraps the error (with the rung and its
delta); the `run()` and `type = "mc"` paths propagate it bare.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | New argument `on_error = c("stop", "continue")`, default `"stop"`. | Grill Q1 = (c). The default keeps today's behavior: the sweep aborts on the first failure. |
| D2 | **Scope: the fit-and-infer stage of a rung**, i.e. `run()`, `pool()` and `infer()`, for both `type = "mc"` and `type = "mbco"`. Re-imputation and the finiteness check (`.mnar_reimpute`, `.mnar_check_finite`) are **not** caught: they are grid or imputation-model problems that would fail every rung, so they always stop. | Q1 was asked about MBCO only. A lavaan non-convergence refuses inside `run()` for both types, so limiting `"continue"` to the MBCO branch would leave the most common failure uncovered. **Author to confirm D2.** |
| D3 | Catch **`error` conditions only**: `tryCatch(error = )`. Warnings, messages and interrupts pass through. | A broader handler would swallow user interrupts and turn warnings into failures. |
| D4 | Under `"continue"` a failed rung stores `NULL` in `@rungs[[i]]` and its message in a new property `@failed` (character, one per rung, `NA` when the rung succeeded; default `character()` meaning "none failed"). | A fake placeholder would have to satisfy the `MbcoMIResult` class and the `Estimate`/`CI` shape, and `print()` reads `@rungs[[1]]@ariv`. `NULL` plus `@failed` is the honest representation and the reader code is small (section 4). |
| D5 | If **every** rung fails under `"continue"`, error: the message names the count and the first failure. A result with no successful rung is not a sensitivity curve. | The validator already requires at least one rung; make the reason explicit instead of an opaque validator message. |
| D6 | Error text for a failed rung is `sensitivity rung i of n (delta = ...): <original message>` in both modes. The MBCO message is byte-identical to today's; the `run()` and `mc` errors gain the same prefix (an additive change: the original message is still contained). | One format; the user can find the rung. |
| D7 | Under `"continue"` the function emits **one** warning after the sweep: `sensitivity_mnar(): k of n rung(s) failed (rungs 3, 7); see $failed or tidy()`. | A silent partial curve is the failure mode that made option (b) of Q1 unattractive. |

## 3. Behavior

- `on_error = "stop"` (default): unchanged, apart from D6's prefix.
- `on_error = "continue"`: each rung runs in a `tryCatch`; on error the rung is recorded as failed and the loop continues. The grid, `@msp` (computed before fitting, so it is available for failed rungs) and the pinned seed are unchanged.
- Per-rung seed pinning: each rung re-imputes with the same `seed` (`.mnar_reimpute(mids, grid[i, ], seed)`), so a rung's result does not depend on earlier rungs having succeeded. The known-answer test in section 6 verifies this rather than assuming it.

## 4. Result class and readers

Only these sites read `@rungs`:

| Site | Change |
|---|---|
| `R/MDSensitivityResult.R` validator | New property `failed` (`class_character`, default `character()`). Validator: `@failed` is empty or one per rung; a `NULL` rung is allowed only where `@failed[i]` is not `NA`; the `Estimate`/`CI` or `D4`/`p` name check skips failed rungs; at least one rung must have succeeded. |
| `tidy()` (`R/methods-output.R:~247`) | Failed rungs give `NA` for `estimate`/`conf_*` or `D4`/`p_value`. A column `error` (the message, `NA` when fine) is added **only when some rung failed**, so the table for a clean run is unchanged. Add `"error"` to `.mnar_tidy_reserved` (a target may not be named `error`). |
| `print()` (`R/methods-output.R:~96`) | Read `ariv` from the first non-`NULL` rung. Add one line, `failed rungs: 3, 7`, when any failed. |
| `summary()` (`R/methods-output.R:~125`) | Failed rungs already take the "unknown verdict" path (`NA` interval or p-value: the tipping point is reported only if every such rung lies farther from MAR than it, otherwise it is undetermined and the NA rungs are named). Verify the failed rungs are named as failures, and that **a gap is never interpolated across**. |

No other code reads `@rungs`.

## 5. Not in scope

- Retrying a failed rung with different settings, or a per-rung retention policy.
- Catching failures in `.mnar_reimpute()` (always stop, D2).
- Changing the default to `"continue"`.

## 6. Acceptance and verification

1. **Default unchanged.** With `on_error` omitted, a planted failing rung aborts with the existing MBCO message byte-for-byte; every existing `sensitivity_mnar()` test passes unmodified.
2. **Known-answer test that can fail (bit-identity).** Grid `c(-1, 0, 1, 2)` with a planted failure at one rung. For every successful rung, `tidy()` under `"continue"` equals the same rung's row from `"stop"` run on the grid **without** the failing delta (`expect_identical`). This proves the continue path does not perturb successful rungs and that per-rung seeding is independent. The planted failure reuses the non-convergence trigger in `tests/testthat/test-mbco-convergence.R`.
3. **All rungs fail.** `"continue"` errors (D5); `"stop"` errors on the first.
4. **Condition classes (D3).** A warning raised inside a rung is not turned into a failure; an interrupt-class condition is not caught.
5. **Readers.** `tidy()` gains `error` only when a rung failed; `print()` works when rung 1 failed; `summary()` reports the tipping point as undetermined (not interpolated) when a failed rung lies between retained and rejected rungs.
6. **`type = "mc"` and `engine = "lavaan"` paths.** `"continue"` keeps successful rungs when `run()` refuses a non-converged lavaan imputation (one test each for `mc` and `mbco`).
7. **Validator.** An object built with a `NULL` rung and no `@failed` entry for it is rejected.
8. **Docs.** `?sensitivity_mnar` (the `type` paragraph currently says the sweep stops and no partial result is returned), `vignettes/articles/sensitivity-mnar.Rmd`, `refcard.Rmd` (the refcard test executes its catalog: add the row and let `test-refcard-matrix.R` run it), NEWS under New features, `_pkgdown.yml` unchanged (no new export).
9. **Gate.** `devtools::check()` 0/0/0 in the tree the PR ships from, and an E2E with a planted failing rung quoted in the PR body (`e2e-before-pr.md`): output of `on_error = "stop"` and `"continue"` on the same grid, plus the warning of D7.

## 7. Risks

| Risk | Mitigation |
|---|---|
| A partial curve is read as complete | D7 warning, `error` column, `print()` line, `summary()` never interpolates |
| `NULL` in a `class_list` property | Test 7; S7 stores `list(NULL)` elements, and the loop assigns with `rungs[i] <- list(NULL)`, never `rungs[[i]] <- NULL` (which would delete the element) |
| D6 prefix changes bare `run()` messages | Additive; check existing `expect_error` patterns in `tests/testthat/test-sensitivity-mnar.R` and `test-lavaan-*.R` during implementation |
| Rung results depend on RNG state left by a failed rung | Test 2 compares bit-for-bit; if it fails, reseed before `run()` instead of relying on `.mnar_reimpute()` |

## 8. Tasks

| Task | Size | Notes |
|---|---|---|
| T1 result class + validator + readers (`tidy`, `print`, `summary`) | S | Tests 5 and 7 first |
| T2 `on_error` in the loop, D5 and D7 | S | Tests 1-4 and 6 |
| T3 docs, NEWS, refcard row | XS | Item 8 |
| T4 gate and E2E | XS | Item 9 |

One PR (`feature/sensitivity-on-error` to `dev`, squash).
