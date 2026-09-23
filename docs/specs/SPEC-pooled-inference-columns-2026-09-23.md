# SPEC: Rubin inference columns in the pooled `tidy()` table

| | |
|---|---|
| **Status** | IMPLEMENTED 2026-09-23 on `feature/pooled-inference` (decisions Q1–Q4 grilled the same day) |
| **Source** | Item 3 of `PLAN-parked-findings-2026-08-30.md` (deferred with five blockers) |
| **Affects** | `R/pool.R` (`pool()` for `MDMediationFit`), `R/MDMediationResult.R` roxygen, NEWS |
| **Target** | v0.4.0 |

## 1. The gap

On `dev` (`02c921c`), `pool()` builds `tidy_table` with
`term, estimate, std_error, var_w, var_b, var_tot`. `R/MDMediationResult.R:11-12`
documents a `p_value` column that has never existed. With `Y ~ X + M + C` and
`M ~ X + C` the table has 10 rows: `m_(Intercept), m_X, m_C, y_(Intercept), y_X,
y_M, y_C, a, b, c_prime`. `a`, `b` and `c_prime` are exact copies of `m_X`,
`y_M` and `y_X` (verified).

## 2. Decisions

| # | Question | Decision | Rejected |
|---|---|---|---|
| Q1 | Column names | Add `statistic`, `df`, `riv`, `fmi`, `p_value` (snake_case, fulfils the documented promise) | distinct names (`p_wald`); df/fmi only, with no p-value |
| Q2 | Degrees of freedom | **Barnard–Rubin (1999)**. The complete-data df `dfcom` is set **per model**: the mediator model's residual df for `m_*` rows and the outcome model's for `y_*` rows. It is `Inf` for fixed-dispersion families (binomial, poisson), matching `summary.glm`'s z-tests. | Rubin (1987) only (df too large at small n); one df for all rows |
| Q3 | Alias rows `a`/`b`/`c_prime` | **Keep and fill every column**, repeated values included; the roxygen documents them as aliases | drop them (breaks `term == "a"` filters); NA on alias rows |
| Q4 | `m = 1` (IPW, single imputation) | **Single-fit Wald test**: `riv = fmi = 0`, `df = dfcom`, p from t(dfcom), or z when `dfcom = Inf`; keep the explicit `m == 1` branch | all NA (what `pool.scalar` does); refuse |

## 3. Formulas (per term, using diagonals)

With `Ubar` (within), `B` (between) and `T = Ubar + (1 + 1/m) B`:

- `riv = (1 + 1/m) B / Ubar`, and `lambda = (1 + 1/m) B / T`
- `df_old = (m - 1) / lambda^2`
- `df_obs = (dfcom + 1) / (dfcom + 3) * dfcom * (1 - lambda)`
- `df = df_old * df_obs / (df_old + df_obs)`, which reduces to `df_old` when `dfcom = Inf`
- `fmi = (riv + 2 / (df + 3)) / (riv + 1)`, as in `mice::pool.scalar`
- `statistic = estimate / std_error`, and `p_value = 2 * pt(-abs(statistic), df)`, using `pnorm` when `df = Inf`

Edge cases:

- `m = 1`: `df_old` is 0/0, so take Q4's branch.
- `B = 0` with `m > 1`: `lambda = 0`, `df_old = Inf`, and `df = df_obs`.

**Compute these by hand, vectorized, and do not call `pool.scalar`.** It works on one
scalar per call, returns no statistic or p-value, and gives NA at `m = 1`. The tests
cross-check against `mice::pool.scalar(Q, U, n = dfcom + k, k = k)` for `m > 1`.

## 4. Implementation questions (not decided)

- **Where `dfcom` comes from (checked 2026-09-23).** `medfit::MediationData` has
  no `df.residual`. It does carry `n_obs`, `family_m`, `family_y` and the named
  estimates, so use `dfcom_m = n_obs - sum(startsWith(nms, "m_"))` and the same
  for `y_`. The count includes the intercept term, so it equals the model's
  column count. The weakness: this assumes medfit keeps the `m_` / `y_` prefix
  convention, so pin it with a test.
- **The dispersion rule for `dfcom = Inf`.** Key it off `family_m` / `family_y`:
  gaussian (and quasi-*) are finite, binomial and poisson are `Inf`.

## 5. Documentation carried with the change

- **Per-path only.** These are per-path (a, b, c') Wald quantities, **not a test of
  the indirect effect**: `a*b` is nonlinear and its null is non-regular, which is
  why the MC CI and MBCO exist. The roxygen says so next to the column list, and
  vignette section 3 notes it.
- **NEWS**, in one line: `p_value` is a Rubin-pooled Wald test, not the S4
  geometric mean of per-imputation p-values.

## 6. Acceptance criteria

- [x] At `m > 1` with gaussian models, `df`, `riv` and `fmi` match
      `mice::pool.scalar` to 1e-10 for every term.
- [x] `m_*` rows use the mediator model's `dfcom`, and `y_*` rows the outcome model's.
- [x] With a binomial `family_m`, the `m_*` rows have `dfcom = Inf`, and `df`
      equals Rubin's 1987 df.
- [x] At `m = 1`, the p-values match `summary.glm()` for a gaussian fit on the
      same data, with `riv = fmi = 0`.
- [x] The alias rows equal their source rows in every column.
- [x] n = 200: `df` is at most `dfcom`, which is the regression test for `df = 4802`.
- [x] `R CMD check --as-cran` 0/0/0, and the suite is green with strictly more tests.

## 7. Implementation record (2026-09-23)

- `R/pool.R`: `.pool_wald()`, which uses the formulas in section 3 (mice's
  `barnard.rubin()` form) and derives `dfcom` from the prefixes as in section 4.
- `tests/testthat/test-pool-inference.R`: 8 blocks, 37 expectations. All 8
  failed on `da3f019`. Three had first passed vacuously because `all()` of an
  empty vector is TRUE, and were tightened to require the new columns.
- E2E against the standard mice workflow: `summary(mice::pool(with(imp,
  lm(...))))` on the same imputations gives the same df and p-values within
  1e-13 on all 7 coefficients. That independently confirms that
  `n_obs - k` matches `lm`'s residual df.
- `devtools::check()` 0/0/0; `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 320 ]`, up from 283.
