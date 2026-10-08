# GRILL: SEM engine spec, section 4 (open questions)

| | |
|---|---|
| **Target** | [SPEC-s7-sem-engine-2026-09-23.md](SPEC-s7-sem-engine-2026-09-23.md), section 4 |
| **Date** | 2026-10-07 |
| **Status** | Done: G1-G7 locked; folded into the spec's section 4 |

## Draft decisions entering the grill (author, 2026-10-07)

1. IPW with lavaan: **allowed**, via `lavaan::sem(sampling.weights =)` on the
   complete cases.
2. `sensitivity_mnar()`: `type = "mc"` works (one test); `type = "mbco"` inherits
   the Q4 refusal.
3. Validation: `lavaan::lavaanify()` before fitting; treatment and mediator must
   appear, and the `mediator ~ treatment` and `outcome ~ mediator` regressions
   must exist (the mediator may be latent).
4. Convergence: refuse, naming the non-converged imputations; the glm path is
   unchanged.

## Evidence gathered

- medfit 0.4.0's `fit_mediation()` accepts `engine = "glm"` (the default) and
  `"regmedint"` (`checkmate::assert_choice(engine, choices = c("glm",
  "regmedint"), ...)`); 0.3.2 accepted `"glm"` only. Neither is an SEM engine,
  so the lavaan path still fits with `lavaan::sem()` and converts with
  `medfit::extract_mediation()`.
- The glm path records non-convergence only (`pool()` sets
  `@converged <- all(...)`); it neither warns nor errors.
- IPW probe (n = 500, MAR on M, missingmed's own `.ipw_weights()`): glm IPW
  a = 0.5152 (SE 0.1069), b = 0.3295 (SE 0.0513); lavaan
  `sampling.weights` on the same complete cases a = 0.515 (SE 0.106),
  b = 0.330 (SE 0.050). With weights, lavaan's default is ML with
  `se = "robust.huber.white"`. Both engines treat the estimated weights as
  known, so the lavaan route adds no SE caveat the glm IPW path lacks.

## Decision ledger

| # | Question | Decision | Rejected |
|---|---|---|---|
| G1 | IPW + lavaan: what if `...` asks for a non-robust `se`/`estimator`? | **Force robust SEs**: the IPW path sets `se = "robust.huber.white"` and errors if `...` requests a non-robust `se` or an estimator without a sandwich. Fit on the complete cases only, as the glm IPW path does. | allow the override (silent naive SEs); warn on override (warnings get lost in pipelines) |
| G2 | Converged but improper (negative residual variance / Heywood) in some imputations | **Warn once**, naming the imputations (from `lavaan::lavInspect(fit, "post.check")`), collecting lavaan's per-imputation warnings into that one message; pooling proceeds. Non-convergence still refuses (draft 4). | refuse (fragile for latent mediators at m >= 20); pass lavaan's raw warnings through (m unnumbered warnings, easy to miss) |
| G3 | Which variable is the outcome? (medfit's lavaan extractor silently takes the first variable regressed on the mediator, `b_row$lhs[1]`) | **`outcome` is a required argument** of `set_md_mediation()` when `engine = "lavaan"`, validated against `lavaanify()` before fitting (it must regress on the mediator) and always passed to `medfit::extract_mediation()`. Amends spec Q1's signature. | optional and inferred when unambiguous (author preferred one explicit rule); refusing multi-outcome models |
| G4 | `sensitivity_mnar()` with a latent mediator (`target` defaults to the mediator, which has no data column) | **Require an explicit observed `target`**: with `engine = "lavaan"` and a latent mediator, `target = NULL` errors before re-imputing and lists the indicators; an explicit target works as for glm. | default to all indicators (silently defines a new sensitivity parameter); refuse latent mediators in sensitivity |
| G5 | Release scope (the spec's v0.5.0 target is stale) | **Both in 0.6.0**: the lavaan engine (with IPW, G1) and the removal of the S4 API, which drops the `OpenMx` import, ship together. | lavaan in 0.6.0 and S4 removal in 0.7.0 (one overlap release for `set_sem()` users); deferring IPW + lavaan |
| G6 | Engine choice (spec Q1 reopened: why not OpenMx?) | **lavaan only** in 0.6.0; Q1 stands. An OpenMx engine is later work and starts with an OpenMx extractor in medfit. Checked 2026-10-07: medfit has a lavaan `extract_mediation()` method and no OpenMx code (OpenMx is not among its dependencies); RMediation's complete-data `mbco()` is OpenMx-only, which matters to the future SEM-MBCO spec, not to D4-MBCO (missingmed refits itself). | both engines in 0.6.0 (needs a new extractor, keeps the OpenMx import, reverses G5); OpenMx instead of lavaan (no extractor at all) |
| G7 | How the S4 removal reaches users in 0.6.0 (no overlap release) | **`.Defunct()` stubs** for the removed S4 exports in 0.6.0, each naming its replacement (`set_md_mediation(..., engine = "lavaan")`, `run()`, `pool()`; "no replacement" for the OpenMx path); the stubs are deleted in 0.7.0. | deleting outright in 0.6.0 (old scripts fail with "could not find function" and no guidance) |

## Open Questions

- Whether medfit should own the lavaan fit itself (a `fit_mediation(engine =
  "lavaan")`) rather than missingmed calling `lavaan::sem()` and then
  `extract_mediation()`; not needed for 0.6.0.
- The SEM-MBCO follow-up spec (spec Q4) is unchanged: constrained refits, the
  latent-mediator meaning of b = 0, a lavaan parity test.
