# NOTE: stacking the weight-model score in the IPW standard errors (2026-10-09)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Plan item** | E in [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md); decision Q4 in [GRILL-open-items-2026-10-09.md](GRILL-open-items-2026-10-09.md): stack the weight-model score |
| **Status** | Design. Steps 1-3 of section 8 implemented 2026-10-09 (`.ipw_weights_info()`, `.ipw_stacked_vcov()` in `R/ipw_stack.R`, not yet wired into `run()`; tests `test-ipw-stack.R`; oracle `dev/ipw-stack-oracle.R`, results in section 9). Nothing in medfit or RMediation was edited (both read-only for this note). |
| **Reads** | `medfit/R/fit-glm.R:411-420`, `medfit/R/extract-lm.R:70-90, 396-434, 768-780`, `medfit/R/classes.R:82-120` (medfit `dev`, `2767072`); `RMediation::ci_mediation_data` (installed 1.6.1); `R/ipw_run.R` here. |

## 1. The question, answered

**Does medfit's `se_type = "sandwich"` stack the weight-model score? No.**

- `fit_glm` builds `vcov_fun <- function(m) sandwich::vcovHC(m)` (`R/fit-glm.R:419`) and applies it to each weighted fit separately. `vcovHC` on a weighted `glm` treats the weights as fixed numbers. The score of the missingness model never enters.
- medfit stores the two equations' covariances **block-diagonally**, so `cov(a, b) = 0` (`R/extract-lm.R:73-76, 434`). Its own docs call that exact only for OLS when each later equation contains every regressor of the earlier one. With estimated weights shared across both fits that argument does not carry over (section 4.3).
- missingmed's IPW docs already say the weights are "treated as known" (`vignettes/articles/ipw-weighting.Rmd:104-107`). The finding confirms that sentence is literally true of the code path.

Consequence: the stacked fix needs **no medfit change and no RMediation change**.

- missingmed already estimates the weights (`.ipw_weights()`, `R/ipw_run.R`) and receives a `medfit::MediationData` whose `@vcov` is a settable matrix (`R/classes.R:93`).
- `RMediation::ci_mediation_data` takes the 2x2 `a`, `b` block of `@vcov` (`.extract_path_vcov(object, c("a", "b"))`) and passes it to `ProductNormal`, so a non-zero `cov(a, b)` in `@vcov` reaches `infer(type = "mc")` as is.

Not verified: the direction and size of the current bias in this package. Theory (Robins, Rotnitzky and Zhao 1994; Lunceford and Davidian 2004 for the propensity analogue) says that ignoring estimation of correctly specified weights is conservative for each coefficient, but the effect on the product `a*b` also depends on `cov(a, b)`, whose sign is not fixed. Treat "conservative" as an expectation to be measured by the gate in section 6, not a result.

## 2. Estimator to implement (glm engine)

Notation: `R_i` observed-complete indicator, `z_i` the missingness-model design row, `p_i = P(R_i = 1 | z_i; gamma)`, `w_i` the weight, `s_i(theta)` the casewise score of the weighted outcome or mediator regression (`x_i * residual_i / dispersion` for the GLM), `theta = (theta_m, theta_y)`.

Estimating equations, stacked:

- weight model: `S_i(gamma) = z_i (R_i - p_i)` over **all** n rows (the model is fitted on every row);
- numerator model (stabilization only): `T_i(delta) = t_i (R_i - q_i)` over all rows, with `q_i = P(R_i = 1 | treatment; delta)`;
- regressions: `psi_i(theta; gamma, delta) = R_i * w_i * s_i(theta)` over complete cases.

With estimated `gamma`, `delta`, the influence function of `theta_hat` is

`IF_i = A^{-1} ( psi_i + C_gamma A_gamma^{-1} S_i + C_delta A_delta^{-1} T_i )`

(derived from `0 = mean psi(theta_hat, gamma_hat) ~ mean psi - A (theta_hat - theta) + C (gamma_hat - gamma)` and `gamma_hat - gamma ~ A_gamma^{-1} mean S`, so the corrections are **added** when `C` is the derivative as defined here) where `A = -E[d psi / d theta]` (the usual weighted bread), `A_gamma = E[z z' p (1 - p)]` (information of the missingness model), `A_delta` likewise, and `C_gamma = E[d psi / d gamma]`, `C_delta = E[d psi / d delta]`. The variance is `n^{-1} * mean(IF_i IF_i')` over the n rows, with `IF_i = 0` contribution of `psi` for incomplete rows (they still carry the `S_i` and `T_i` terms).

Closed forms (logit missingness model), so no numerical differentiation:

| Weight form | `d w_i / d gamma` | `d w_i / d delta` |
|---|---|---|
| `w = 1 / p` (unstabilized) | `-w (1 - p) z` | none |
| `w = q / p` (stabilized) | `-w (1 - p) z` | `w (1 - q) t` |
| per-variable `p = prod_v p_v` | `-w (1 - p_v) z_v`, one block per variable `v` | as above with `q = prod_v q_v` |

so `d psi_i / d gamma = R_i s_i(theta) * (d w_i / d gamma)'`.

The joint IF for `theta = (theta_m, theta_y)` gives the **full** covariance, including the `theta_m`-`theta_y` block that medfit sets to zero. Write that matrix into the pooled `MediationData@vcov` (same ordering medfit uses), leaving estimates unchanged. The `c_prime`, `a`, `b` standard errors and the `a`-`b` covariance then all come from one object.

HC3 versus HC0: medfit uses HC3 (leverage-inflated). The stacked estimator above is HC0-type. No small-sample correction is claimed; the gate (section 6) decides whether one is needed, and lavaan's `information_meat_hc` (see the lavaan tutorial) is a precedent for offering one.

## 3. Where it lives and how it plugs in

- New internal in missingmed (suggested file `R/ipw_stack.R`): `.ipw_stacked_vcov(object, w_info, fit)`. `.ipw_weights()` must return what the variance needs, not just `w`: the fitted `p`, `q`, the design rows `z`, `t`, and which rows were trimmed. Return them as an attribute or a list so the existing `w` contract does not change.
- The regression scores `s_i(theta)` come from refitting nothing: for a glm with estimates in `MediationData@estimates`, compute them from `cc_data`, the stored formulas and the estimates. Check at implementation that this reproduces `sandwich::estfun()` on a weighted `glm` to 1e-10 before trusting it (known-answer test).
- `run()` for `method = "ipw"` stores the stacked matrix; `pool()` (m = 1) passes it through. The `se_type = "sandwich"` option keeps its meaning (robust to heteroskedasticity); add an option name only if both estimators stay available. Recommend a `weights_known = FALSE` style argument on `set_md_mediation()` (default: stack), with `TRUE` reproducing today's SEs for comparison. This changes IPW standard errors by default, so NEWS must say so, and the change is user-visible even though the point estimates are not.
- `infer(type = "mc")` needs no change. `infer(type = "mbco")` still refuses IPW.

## 4. The three things the grill asked this note to cover

### 4.1 `weight_trim` (non-smooth quantile cap)

`w_i = min(w_i, cap)` with `cap` the empirical `weight_trim` quantile of the complete-case weights. The cap depends on `gamma` through the whole sample, and the quantile is not differentiable.

Options:

1. **Treat trimmed rows as constants** (`d w_i / d gamma = 0` for capped rows) and ignore the cap's own estimation. Simple, closed form, slightly anti-conservative for the capped rows' contribution.
2. Estimate the quantile's influence (needs a density estimate at the cap; unstable).
3. Refuse stacking when `weight_trim < 1` and keep known-weights SEs with a message.

**Recommend option 1**, documented as an approximation, with a dedicated calibration cell (`weight_trim = 0.95`) in the gate. If that cell fails, fall back to option 3 for trimmed fits.

### 4.2 Stabilization (extra numerator model)

The numerator `q_i` is a second estimated model (treatment-only logit), so stabilized weights carry a second nuisance score `T_i` and a second correction term (table in section 2). Omitting it is a distinct error from omitting the missingness-model score; the stacked estimator includes both. Stabilization changes `w` by a constant factor per treatment level, so `C_delta` is not small in general (it shifts the weights of one arm).

### 4.3 The `a`-`b` covariance

Both regressions use the same weights, so the same `S_i` (and `T_i`) term enters both influence functions. Their covariance is the sum of (i) the score cross-moment `E[psi_m psi_y']`, which is zero when the mediator and outcome errors are independent given the covariates, and (ii) the shared-weight correction `C_{gamma,m} A_gamma^{-1} C_{gamma,y}'` plus the `delta` analogue, which is generally non-zero. So the block-diagonal storage is only a good approximation when weight-estimation uncertainty is small. The sign of (ii) is not fixed, which is why the effect on the `a*b` interval has to be measured (section 6) and not assumed to be conservative.

## 5. Other engines

- **glm** (all families missingmed supports): in scope. Closed forms above; `s_i` is the usual GLM score, the dispersion handled as in `vcovHC` (Gaussian) or fixed (binomial, Poisson).
- **lavaan** (`sampling_weights`): lavaan's robust SEs also treat the weights as known. Stacking needs casewise scores that include the weight, from `lavaan::lavScores()`. **Not verified** whether `lavScores()` returns weighted scores under `sampling_weights` in 0.7-3, or whether `vcov(fit)` can be rebuilt from them to match lavaan's own sandwich. Test that first; if it does not hold, lavaan IPW keeps known-weights SEs and the docs say so. Recommend glm first, lavaan as a second PR.
- **regmedint** (if reachable through IPW): refused today by medfit for weights; nothing to do.

## 6. Validation gate (hopper, same pattern as item B)

Pre-register before running; positive control and per-column NA share recorded (see memory note on dropped replications).

1. **Known-answer unit test (laptop, fast):** on a weighted glm with weights treated as known (set `C_gamma = 0`) the stacked code must equal `sandwich::vcovHC(type = "HC0")` to 1e-10.
2. **Oracle check (laptop):** on 5 datasets, stacked SEs for `a`, `b`, `cov(a, b)` versus a nonparametric bootstrap of the whole pipeline (re-estimate weights, trim, refit), 500 resamples. Agreement within Monte-Carlo error is the correctness bar; the bootstrap is also the fallback estimator if the analytic one cannot be made to agree.
3. **Coverage grid (hopper):** `mc` interval for `a*b` under MAR missingness in the mediator, `n` in {200, 500}, missingness in {25%, 40%}, stabilized and not, `weight_trim` in {1, 0.95}, null and non-null `a`, `b`. 1000 replications per cell. Compare known-weights and stacked: report size, coverage, interval width, and the share of replications where the stacked variance for `a*b` was non-positive or non-finite.
4. **Criteria to fix in advance:** stacked size at or below 0.065 (Monte-Carlo se about 0.007) everywhere; stacked not worse than known-weights in any cell; if known-weights is already within tolerance in every cell, the change is justified on correctness alone and the NEWS says SEs may move either way.

## 7. Risks and open points

- Misspecification: the stacked variance assumes the missingness model is correct. Known-weights SEs are conservative under correct specification but neither estimator is robust to a wrong one.
- Many small weights or near-separation in the missingness logit make `A_gamma` ill-conditioned; guard with the same non-convergence refusal missingmed already uses for glm refits, and report a clear message.
- Default change: stacked SEs by default alters existing IPW results. Version this as a minor bump with an explicit NEWS entry and the `weights_known` escape hatch.
- Dependency: no new package. `sandwich` stays for the known-weights path.

## 8. Suggested task order

1. `.ipw_weights()` returns the nuisance quantities (no behavior change, tests on the old contract).
2. `.ipw_stacked_vcov()` for glm, unstabilized, no trim; known-answer test (6.1).
3. Add stabilization, per-variable models, trimming approximation; oracle check (6.2).
4. Wire into `run()`/`set_md_mediation()`; docs (`ipw-weighting.Rmd` "Standard errors" section, refcard, NEWS).
5. Hopper gate (6.3); results section appended here.
6. lavaan, only if `lavScores()` supports it.

Effort: M for steps 1-4, plus the hopper run.

## 9. Results: steps 1-3 (2026-10-09)

**Implemented:** `.ipw_stacked_vcov()` now covers stabilized weights (numerator model), per-variable missingness models and trimming by the constant-cap approximation (section 4.1, option 1). Raw output: [RESULTS-ipw-stack-oracle-2026-10-09.txt](RESULTS-ipw-stack-oracle-2026-10-09.txt).

**Exact check (laptop, `test-ipw-stack.R`):** for unstabilized, stabilized, per-variable (stabilized or not) and trimmed fits, the stacked variance equals an independent brute-force stacked M-estimation sandwich (numerical Jacobian of the joint estimating equations; cap held at its fitted value) to 1e-5. Planted defects (numerator sign flipped; trimmed-row handling removed) each fail it.

**Bootstrap oracle (`dev/ipw-stack-oracle.R`, B = 500, n = 500, 8 configurations x 5 datasets = 40 cases).** Bar fixed beforehand: stacked SE / bootstrap SE in [0.90, 1.10] for `a` and `b`, and |corr_stacked(a, b) - corr_boot(a, b)| < 0.10. **39 of 40 pass.**

- Stacked SE / bootstrap SE: `a` 0.905 to 1.016, `b` 0.925 to 1.020 (bootstrap se of an SE is about 3%).
- The one failure: `aux_stab_trim`, dataset 5 (14 trimmed rows): corr(a, b) stacked 0.054 vs bootstrap 0.164, difference 0.110. This is the configuration where the constant-cap approximation matters; with one case it is also within about 2.4 Monte-Carlo se of the correlation, so it is a flag for the hopper gate, not a verdict.
- `cov(a, b)`: the bootstrap correlation of `a` and `b` is as large as 0.42 in absolute value in the auxiliary-variable setting. medfit stores zero. The stacked correlation tracks the bootstrap (max difference 0.11, 0.03 outside the one failing case).
- **The marginal SEs of `a` and `b` barely move.** Stacked / known-weights SE ratio is 0.97 to 1.00 for `a` and 0.96 to 1.01 for `b` even where missingness is driven by an auxiliary variable left out of the regressions, and 0.985 to 1.002 where it is driven by covariates the regressions contain. The bootstrap cannot resolve differences that small: stacked is closer to the bootstrap SE in 8 (`a`) and 9 (`b`) of 20 auxiliary-setting cases, a coin flip. This oracle therefore shows the stacked formula is **correct**, not that it changes the standard errors of `a` and `b` in a way a bootstrap can detect at this size.

**What this means for step 4 (wiring):** the case for the change rests on `cov(a, b)` and so on the `a*b` interval, not on the marginal SEs. The coverage grid of section 6.3 is the test that matters; run it before deciding the default (`weights_known`), and do not claim narrower or wider SEs in NEWS until it has.
