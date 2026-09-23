# GRILL: NARFCS delegation for `sensitivity_mnar()`

| | |
|---|---|
| **Target** | `feature/narfcs-delegation` (dd88c94..06a48ef) against `SPEC-narfcs-delegation-2026-08-29.md` |
| **Date** | 2026-09-23 |
| **Spec** | [SPEC-narfcs-delegation-2026-08-29.md](SPEC-narfcs-delegation-2026-08-29.md) |

## Decision ledger

### D1 — numeric 0/1 target imputed by `pmm` (riskiest assumption)

- **Finding:** such a target stays on the `post` route and is shifted additively.
  A gaussian mediator model silently analyzes imputed 1/2; a binomial one fails
  late in `glm` ("y values must be 0 <= y <= 1").
- **Decision:** **Refuse.** Error when a `post`-routed target's observed values
  are all 0/1, pointing to `method = "logreg"`.
- **Rejected:** warn-and-run (silent case survives); auto-reroute to
  `mnar.logreg` (changes the imputation method, breaks delta = 0 => MAR);
  document only.
- **Consequence:** behavior change — NEWS bullet; vignette self-check 4 rewritten
  around the refusal.

### D2 — which `norm` rungs go through `mnar.norm` (weakest recommendation)

- **Finding:** for a constant delta, `mnar.norm` and `post` give identical draws,
  so delegating constant deltas buys nothing and makes existing curves depend
  on mice keeping `mnar.norm`'s RNG path equal to `norm`'s.
- **Decision:** **`mnar.norm` only when `ums` is given.** A constant delta on a
  `norm` target stays on `post` (`@mechanism_used` = `"post"`).
- **Rejected:** always `mnar.norm` (as built; mice-internals dependency for no
  result change); never delegate `norm` (drops covariate-varying delta for
  continuous targets).
- **Consequence:** the routing function needs to know whether `ums` was
  supplied; spec's routing table and vignette 5B.1 updated to match.

### D3 — when `ums` strings are validated (implementation regret)

- **Finding:** mice parses each `ums` only when its rung runs; a bad later
  string wastes every earlier rung's re-imputation and fit.
- **Decision:** **dry-run each string first** — one `mice(m = 1, maxit = 1)`
  per string before the rung loop, erroring with the offending string named.
- **Rejected:** own parser (duplicates mice's grammar, would need `:::` or drift);
  leave to mice (late failure, no rung named).
- **Consequence:** small upfront cost per rung; test with a bad 2nd string that
  must fail before any rung is fitted.

### D4 — the `scale` argument (reversibility / scope creep)

- **Finding:** `scale` is assertion-only; `@scale`, `print()` and `tidy()` already
  disclose the scale. An exported argument is hard to remove after release,
  easy to add.
- **Decision:** **drop the argument**; keep `@scale` and its display.
- **Rejected:** keep (permanent surface for a one-line user assertion); warn on
  every log-odds run (noise for deliberate choices).
- **Consequence:** deviation from the spec's API section — recorded in its
  implementation notes; NEWS and roxygen drop the `scale` bullet.

### D5 — source of the vignette 5B.4 prevalence table (benefit honesty)

- **Finding:** the table (0.438 / 0.683 / 0.845) was pasted from a session probe;
  nothing regenerates it.
- **Decision:** **live chunk for 5B.4** (m = 5, ~1 s), table and the "added N
  points" prose via inline R.
- **Rejected:** convert 5B.2 + figure too (widens the branch — separate pass);
  keep hard-coded (silent staleness).
- **Consequence:** ~1 s more vignette build, including on CRAN.

## Adversarial review (2026-09-23, OpenCode `big-pickle`, plan agent, read-only)

Findings re-verified locally (mice 3.19.0) before being recorded here:

- **R1 (amends D3) — a `ums` coefficient typo yields NA imputations, silently.**
  `ums = c("0", "0.5 + garbageZZ*C")`: `parse.ums()` coerces `" garbageZZ"` to
  NA with only a *warning*, every imputed value in that rung is NA, and the rung
  still reports a finite D4 = 16.2 (p = 5.6e-5) — the fit drops the NA rows, so
  the rung is silently a complete-case analysis. `msp = NA` is the only tell.
  A dry run alone would **pass** this string. **D3 must also treat a `parse.ums`
  warning as an error and reject any NA in the probe's imputations.**
- **R2 — `tidy()` overwrites grid columns named `msp`, `mechanism` or `scale`.**
  Target named `msp`, `delta = c(0, 2)`: the delta column is gone from `tidy()`,
  replaced by the realized msp. Needs a guard (refuse such target names, or
  build the table without name collisions).
- **R3 — an NA `delta` is accepted.** `delta = c(0, NA)` runs; rung 2 gets
  `msp = NA`. `.mnar_grid()` must reject non-finite deltas (it already rejects
  NA in `ums`).
- Confirmed as already decided: D1 (reviewer reproduced 1/2 imputations under
  gaussian), D2 (RNG-parity dependence), D5 (hard-coded table).
- Latent, not acted on: a >2-level factor imputed by `logreg` passes the guard,
  but mice itself errors at baseline, so it needs a hand-edited `mids`.

## Checkpoint C re-review (2026-09-23, OpenCode `big-pickle`, plan agent, read-only)

Scope: `8e7b1ff` (ums probe, non-finite delta, reserved names) and `5cbf9e2`
(D6), the two commits the first review never saw. **No HIGH findings, and no
regression introduced by either commit.** Items C3 and C4 were reproduced locally.

- **C1 (MED, forward-compat).** The probe promotes a warning only when
  `deparse(conditionCall(w))` names `parse.ums`, which is correct for mice 3.19.0.
  If a future mice moves the coercion, the NA-imputation check still catches it.
- **C2 (MED, coverage boundary, predates these commits; FIXED `e8de230`).** The `maxit = 1`
  probe cannot see NaN/Inf that only appear from iteration 2 onward.
- **C3 (LOW, reproduced; FIXED `06fdfde`).** The reserved-name check ran before
  `.mnar_check_targets()`. As a result `delta = data.frame(msp = ...)` on data
  with no `msp` column reports a tidy() clash, not "not a column". The check
  also refuses `D4` or `p_value` under `type = "mc"`, where nothing is
  overwritten. That second behavior is intended: P2 chose one fixed list.
- **C4 (LOW, reproduced, intended by D6).** A 0/1 target imputed by `mean` has
  continuous support, so D6 allows it on `post` (`@mechanism_used = "post"`),
  where D1 used to refuse it.
- **Verified not real:**
  - probe RNG and seed (mice re-seeds on every call);
  - probe vs. rung `blots` merge;
  - `imp` keyed by variable, not block;
  - empty `imp` (refused upstream when nmis = 0);
  - integer vs. double;
  - zero-row and list-column grids;
  - the probe muffling warnings (the real rungs re-emit them).

## Plan grill (2026-09-23, against `tasks/plan.md`)

| # | Question | Decision | Rejected |
|---|---|---|---|
| P1 | D1 scope | Refuse **any** `post`-routed 0/1 target (pmm, norm, norm.nob, cart, ...) | a pmm/cart/sample list (drifts); pmm only |
| P2 | R2 fix | **Refuse** target names that collide with `tidy()` columns | `delta_<target>` prefix (schema break); suffix on collision |
| P3 | `scale` removal | **Delete, no stub** — it was never released | explicit refusal in `...`; validating all of `...` (out of scope) |
| P4 | E2E form | **Planted defects + known answers**: the 4 reproductions must error; 3 routes reproduce MAR at delta = 0 | route transcript only (can't fail); fresh-context agent trial (later) |
| P5 | E2E home | Committed **`dev/e2e-narfcs.R`** (`^dev$` already build-ignored) | testthat only; leave in the session scratchpad |
| P6 | `tasks/` | **gitignore + `^tasks$` in .Rbuildignore**, like ORCHESTRATE | commit and delete before merge; move to docs/specs |

Closed 2026-09-23, not a bug: `sensitivity_mnar()`'s `...` does **not** swallow
unknown arguments. A misspelled argument such as `levle = 0.9` errors with
`unused argument` at the first rung, because medfit forwards `...` to `glm()`.
Valid arguments such as `se_type` pass through.

## Status: implemented (2026-09-23)

| Item | Commit |
|---|---|
| T0 E2E gate `dev/e2e-narfcs.R`, `tasks/` ignored (P5, P6) | `7399cef` |
| D2 routing by delta kind | `b219596` |
| D1 / P1 refuse `post`-routed 0/1 | `6af2224` |
| D3 + R1 `ums` probe; R3 non-finite delta; R2 tidy name clash | `8e7b1ff` |
| D4 / P3 drop `scale` | `2889536` |
| D5 live 5B.4 table | `15d9b1e` |
| D6 0/1 guard reads the imputations' support (amends P1) | see NEWS / git log |

## Implementation order (for /craft:plan)

1. D2 routing change (constant-delta `norm` → `post`) + update equivalence test and
   `@mechanism_used` expectations.
2. D1 refusal for `post`-routed 0/1 targets + test + NEWS + self-check 4.
3. D3 + R1 `ums` dry-run validation — `parse.ums` warnings are errors, NA probe
   imputations are errors — + tests (bad 2nd string, NA-coefficient string).
3a. R3 reject non-finite `delta`; R2 tidy column-collision guard + tests.
4. D4 drop `scale` argument + tests/roxygen/NEWS.
5. D5 live chunk in 5B.4.
6. Spec implementation notes updated for D2/D4; `devtools::check()` 0/0/0.

## Open Questions

- The 5B.2 table and the sensitivity-curve figure are also hard-coded (predates
  this branch) — candidate for a separate pass.
- A binary **factor** mediator fails in medfit (`M1` vs `M`) — upstream issue.
- **D6 (DECIDED 2026-09-23: data-driven support rule; amends P1) — the 0/1 guard was inconsistent.** With a
  `norm`-imputed 0/1 target, `delta = 1` (post) is refused but `ums = "1"`
  (mnar.norm) runs, though the draws are identical. `norm` + `ums` is the only
  0/1 path that reaches a route other than `post` or `mnar.logreg`. Evidence:
  - The proposed tightening ("refuse any 0/1 not routed to mnar.logreg") only
    removes that path. Under a binomial mediator model that path already fails
    late in `glm`; under a gaussian one it runs.
  - The literature does not support P1's premise that a continuous imputation
    of a binary variable is itself the error. Wu, Jia & Enders (2015, MBR,
    doi:10.1080/00273171.2015.1022644) found normal-model imputation without
    rounding performed well for dichotomous items. Bernaards, Belin & Schafer
    (2007, Stat Med, doi:10.1002/sim.2619) found the normal approximation often
    had satisfactory bias and coverage.
  - The failure D1 exists to stop is a shift that leaves the variable's
    support. Across mice methods, the baseline imputations are all on {0, 1}
    for pmm/cart/sample/midastouch/logreg and continuous for all four `norm*`
    methods (verified, mice 3.19.0).
  - **Candidate rule (data-driven, no method list):** refuse a non-logreg route
    when the baseline mids' imputed values for the target all lie on {0, 1};
    allow it when they are continuous. This fixes the inconsistency and relaxes
    P1 for the `norm*` methods.
