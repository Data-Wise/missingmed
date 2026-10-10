# GRILL: open items after 0.8.0

Plan: [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md). Date 2026-10-09. One decision per row; the recommendation is stated before the answer.

| # | Question | Recommendation | Decision |
|---|---|---|---|
| Q1 | A: failed MBCO rung in `sensitivity_mnar()` | (c) opt-in `on_error = c("stop", "continue")`, default `"stop"` | **(c)**, accepted |
| Q2 | B: glm calibration scope | (a) same 20-cell grid, reuse the hopper harness | ~~(a) same 20 cells~~: the premise was wrong (the lavaan gate was 40 cells; the 20 observed cells are Gaussian, where glm equals lavaan to 1e-10, and the latent cells cannot run on glm). **Re-asked 2026-10-09: glm-specific grid** (binary and count families, `X:M` with `treatment_level`, near-separated fits that still converge), accepted |
| Q3 | C: build MLR? | (a) defer, keep refusing | **(b)** build, simulation-gated (overrode the recommendation) |
| Q4 | E: IPW SEs ignore weight-estimation uncertainty | (a) keep documented, run a coverage check | **(c)** stack the weight-model score (overrode the recommendation). Where it lives is **open**: the weight model is estimated in missingmed (`.ipw_weights()`, `R/ipw_run.R`), so stacking may need no medfit writes. The design note settles that first; it must also cover `weight_trim` (non-smooth quantile cap), stabilization (extra numerator model) and the covariance of `a` and `b` induced by shared weights |
| Q5 | I: CRAN 1.0.0 this year? | decide later | **No**, stay on r-universe. Item I dropped; `.lav_round_nobs()` stays. Side effect: no CRAN constraint, so a GitHub-only medfit can be required through `Remotes:` (name-qualified, see CLAUDE.md) |
| Q6 | H: pkgdown hang | investigate once | **Investigate once**, accepted |
| Q7 | J: AGENTS.md | delete | **Delete**, accepted; done 2026-10-09 (stray worktrees and branches left alone) |
