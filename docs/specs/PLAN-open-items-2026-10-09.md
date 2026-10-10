# PLAN: open items after 0.8.0

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | DECIDED in the grill (section 4). No code written. |
| **Baseline** | `dev` 0.8.0.9000 (`75fcc02`); v0.8.0 released and on r-universe |
| **Sources** | `.STATUS`, `SPEC-sem-mbco-2026-10-08.md` sections 8-11, `PLAN-medfit-0.5.1-cascade-2026-10-08.md`, session notes |

## 1. Inventory

Facts checked 2026-10-09: medfit on CRAN is **0.3.2** (GitHub has 0.6.0 as the latest release); `.lav_round_nobs()` is still in `R/run.R:218`; no open GitHub issues on missingmed.

| ID | Item | Kind | Size | Blocks / blocked by |
|---|---|---|---|---|
| A | A failing MBCO rung aborts the whole `sensitivity_mnar()` sweep; successful rungs are lost | Design gap in a shipped feature | S | none |
| B | glm engine MBCO has never been run through the calibration grid (only lavaan ML was) | Statistical validation | M (hopper) | harness exists (`dev/sim-sem-mbco-*`) |
| C | MLR (T7, T8b): scaled-difference D4, gated by a simulation | New feature | L | A and B do not block it; B's harness extends |
| D | D4 denominator nu vs `mitml`'s df2: never re-verified after the S7 rewrite | Verification | S | none |
| E | IPW sandwich: does medfit's `se_type = "sandwich"` stack the weight-model score (Robins, Rotnitzky and Zhao 1994)? If not, IPW SEs ignore weight-estimation uncertainty | Upstream statistical question | S to read, ? to fix | medfit repo (cross-repo) |
| F | medfit 0.5.1 GitHub release, then drop `.lav_round_nobs()` | Cross-repo cascade | S | CRAN medfit is 0.3.2, so the workaround cannot go until a CRAN release |
| G | Lavaan tutorial: `information_bread` / `information_meat_hc` (lavaan 0.7-3) | Docs | XS | none |
| H | CI: pkgdown `setup-r-dependencies` hung ~25 min twice on push-to-`dev` (3 min on the PR run, same commit) | CI hygiene | S | none |
| I | CRAN submission (1.0.0): decide whether and when | Strategy | M | F (medfit CRAN), E (stat validity), C optional |
| J | Housekeeping: untracked `AGENTS.md`; worktrees `pool-mref`, `quiet-meadow-d4ed`, branch `relicense-lavaan-floor`; stale ecosystem-manifest entry (other repo) | Cleanup | XS | needs per-instance permission |

## 2. Proposed order (before the grill)

1. **A** (S): spec, then implement. Smallest, and a gap in what just shipped.
2. **D** (S): read-only comparison against `mitml`; cheap, and a wrong denominator would invalidate B.
3. **B** (M): glm calibration on hopper, after D.
4. **E** (S): read medfit's sandwich code; open an upstream issue only if the answer is "no".
5. **G, H** (XS, S): small, independent; slot between larger items.
6. **C** (L): only if the grill says MLR is wanted; otherwise leave refused.
7. **F, I, J**: gated on decisions or other repos.

## 3. Grill questions (decision points)

| # | Question | Recommendation |
|---|---|---|
| Q1 | A: what should a failed rung do? (a) keep abort, (b) keep successful rungs and mark failed ones `NA` with the message, (c) opt-in `on_error = c("stop", "continue")` | (c), default `"stop"` so nothing changes silently |
| Q2 | B: calibration scope for glm (cells, nsim) | Same 20-cell grid as lavaan ML, reuse harness |
| Q3 | C: build MLR at all? | Defer; no user has asked, cost is L, refusal is honest |
| Q4 | E: how to treat an affirmative "no stacking" finding | Document the limitation in IPW docs now; upstream issue to medfit |
| Q5 | I: is CRAN 1.0.0 a goal for this year? | Decide after E and F |
| Q6 | H: fix or ignore the pkgdown hang? | Investigate once (cache key and shared concurrency group) before ignoring |
| Q7 | J: AGENTS.md and the three stray refs | Ask per item |

## 4. Decisions (grill, 2026-10-09) and revised order

Ledger: [GRILL-open-items-2026-10-09.md](GRILL-open-items-2026-10-09.md).

| Item | Decision |
|---|---|
| A | `sensitivity_mnar(on_error = c("stop", "continue"))`, default `"stop"`; per-rung status; `"continue"` keeps successful rungs and marks failures `NA` with the message. The spec must state the scope (MBCO refit failure only, or any rung error), catch `error` conditions only, still error when every rung fails, report tipping-point gaps without interpolating, and test that successful rungs are bit-identical to the same rungs under `"stop"` |
| B | **Spec: [SPEC-glm-mbco-calibration-2026-10-09.md](SPEC-glm-mbco-calibration-2026-10-09.md).** glm-specific calibration on hopper (reusing `dev/sim-sem-mbco-*`): binary and count families, `X:M` with `treatment_level`, near-separated fits that still converge. Not the lavaan grid: its observed cells are Gaussian (glm equals lavaan there) and its latent cells cannot run on glm |
| C | Build MLR (T7, T8b), simulation-gated: the gate decides enabled or refused |
| E | Stack the weight-model score. Design note first; it settles whether this lives in missingmed (the weights are estimated in `.ipw_weights()`) or needs medfit (then every write there needs per-instance permission). Must cover trimming, stabilization and the `a`-`b` covariance |
| H | Investigated 2026-10-09: **no fix needed.** Slow, not hung. In the successful rerun of run 37949320808, `setup-r` took ~12 min (apt system requirements 8.5 min, R install 3 min, runner side) and `setup-r-dependencies` 12 min (cold cache for the `dev` ref); the PR-event run on the same commit took 50 s there (warm cache). The rerun wrote the cache (`Cache mode: write`), so later `dev` runs should be warm. Re-open only if it recurs with a warm cache |
| I | Reopened 2026-10-09 as a plan only, gated on E: [PLAN-cran-1.0.0-2026-10-09.md](PLAN-cran-1.0.0-2026-10-09.md). Earlier decision was "dropped: no CRAN this year" |
| J | `AGENTS.md` deleted; the remaining stray worktrees and branches are left to the author |

Revised order: A, D, B, G, E (design note), C (H is closed). F stays a medfit-session task; `.lav_round_nobs()` stays.

Consequence of dropping I: with no CRAN submission, missingmed may depend on an unreleased medfit through `Remotes:` (`Data-Wise/medfit`), which makes E shippable without waiting for a medfit CRAN release.
