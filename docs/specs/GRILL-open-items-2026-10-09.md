# GRILL: open items after 0.8.0

Plan: [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md). Date 2026-10-09. One decision per row; the recommendation is stated before the answer.

| # | Question | Recommendation | Decision |
|---|---|---|---|
| Q1 | A: failed MBCO rung in `sensitivity_mnar()` | (c) opt-in `on_error = c("stop", "continue")`, default `"stop"` | **(c)**, accepted |
| Q2 | B: glm calibration scope | (a) same 20-cell grid, reuse the hopper harness | **(a)**, accepted ("do next" read as taking the recommendation) |
| Q3 | C: build MLR? | (a) defer, keep refusing | **(b)** build, simulation-gated (overrode the recommendation) |
| Q4 | E: IPW SEs ignore weight-estimation uncertainty | (a) keep documented, run a coverage check | **(c)** stack the weight-model score (overrode the recommendation). Cross-repo: the sandwich lives in medfit, so every write there needs per-instance permission; first step is a design note, not code |
| Q5 | I: CRAN 1.0.0 this year? | decide later | **No**, stay on r-universe. Item I dropped; `.lav_round_nobs()` stays. Side effect: no CRAN constraint, so a GitHub-only medfit can be required through `Remotes:` (name-qualified, see CLAUDE.md) |
| Q6 | H: pkgdown hang | investigate once | **Investigate once**, accepted |
| Q7 | J: AGENTS.md | delete | **Delete**, accepted; done 2026-10-09 (stray worktrees and branches left alone) |
