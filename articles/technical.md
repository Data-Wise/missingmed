# Technical reference: design, contracts, and methodology

This vignette is the single technical reference for **missingmed**: the
architecture, the cross-package contracts it depends on, the statistical
methodology of every estimator and inference path, and the engineering
decisions (and their rationale) made along the way. Code blocks are
illustrative (`eval = FALSE`); runnable walkthroughs live in
[`vignette("missingmed")`](https://data-wise.github.io/missingmed/articles/missingmed.md)
and
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

------------------------------------------------------------------------

## 1. Architecture (S7, four verbs, three classes)

missingmed is a **thin orchestration layer**: it runs mediation across
the “missing-data middle” and delegates the statistics outward —
**fitting** to [medfit](https://data-wise.github.io/medfit/),
**inference** to [RMediation](https://data-wise.github.io/rmediation/),
and (later) simulation to medsim. It is written in **S7** to match the
newer ecosystem packages and the shared
[`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html)
contract.

The pipeline is four verbs over three classes:

    set_md_mediation()  ->  run()          ->  pool()             ->  infer()
       MDMediationData       MDMediationFit     MDMediationResult      CI / MBCO
       (data + spec)         (per-imputation    (pooled named          (RMediation
                              named Med.Data)    Med.Data)              or hosted D4)

| S7 class | Carries | S4 ancestor |
|----|----|----|
| `MDMediationData` | data (`mids` or `data.frame`) + mediation spec + estimator/mechanism axes | `SemImputedData` |
| `MDMediationFit` | **list** of per-imputation named [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html) (+ IPW `weights`) | `SemResults` |
| `MDMediationResult` | **pooled** named [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html) + within/between/total vcov | `PooledSEMResults` |

**Orthogonal axes.** The estimator (`method = "mi" | "ipw"`) and the
model (formulas + `engine`) are independent. The same
`run() -> pool() -> infer()` chain serves both estimators; only
[`run()`](https://data-wise.github.io/missingmed/reference/run.md)
branches internally.

``` r

md <- set_md_mediation(data, formula_y = Y ~ X + M + C, formula_m = M ~ X + C,
  treatment = "X", mediator = "M", method = "mi")   # or method = "ipw"
res <- pool(run(md))
infer(res, type = "mc")
```

------------------------------------------------------------------------

## 2. Ecosystem contracts

missingmed produces and consumes objects defined elsewhere. These
contracts are load-bearing — getting the **names** right is what makes
inference work.

### 2.1 `medfit::MediationData` (the fitting contract)

`fit_mediation()` / `extract_mediation()` return a `MediationData` whose
`@estimates` is a **named** numeric vector and `@vcov` a **named**
matrix:

    estimates: m_(Intercept), m_X, m_C, y_(Intercept), y_X, y_M, y_C, a, b, c_prime

The convenience aliases `a` (= `m_X`), `b` (= `y_M`), `c_prime` (=
`y_X`) and the matching `@vcov` dimnames are the interface every
downstream consumer resolves **by name**.

### 2.2 `RMediation` (the inference contract)

> **Namespace note:** the package is `RMediation` (capital R-M), *not*
> `rmediation` — the source repo is `data-wise/rmediation` but
> `DESCRIPTION: Package: RMediation`. Code uses `RMediation::`.

- `ci_mediation_data(mu, level, type, n.mc)` — Monte-Carlo /
  distribution-of-the- product CI from a **single named**
  `MediationData`. Resolves `a`/`b` strictly by name (errors if
  unnamed). This is the `type = "mc"` path.
- `mbco(h0, h1, ...)` — likelihood-ratio MBCO, currently
  **OpenMx-only**; it has no per-imputation / MI entry point (see §4).

### 2.3 Dependency direction (no cycle)

    missingmed  ->  medfit       (fit_mediation, MediationData)
    missingmed  ->  RMediation   (ci_mediation_data, medci)
    RMediation  ->  medfit       (consumes MediationData)
    medsim          (Suggests, later phases)

missingmed imports both medfit and RMediation; neither depends back on
missingmed, so the graph is acyclic.

------------------------------------------------------------------------

## 3. The MI estimator and Rubin’s rules

Under multiple imputation,
[`run()`](https://data-wise.github.io/missingmed/reference/run.md) fits
**every** imputed dataset with
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
yielding a list of `m` named `MediationData`.
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
applies Rubin’s (1987) rules on the **named** vectors so the path labels
survive pooling:

``` math
\bar Q = \tfrac1m\sum_i Q_i,\quad
\bar U = \tfrac1m\sum_i U_i,\quad
B = \tfrac{1}{m-1}\sum_i (Q_i-\bar Q)(Q_i-\bar Q)^\top,\quad
T = \bar U + \left(1+\tfrac1m\right)B .
```

The pooled `MediationData` is built by **copy-modifying** a
per-imputation one (S7 is copy-on-write), replacing only
`@estimates =`$`\bar Q`$ and `@vcov =`$`T`$ — so all medfit metadata
(roles, predictors, families) is inherited and the aliases stay
name-addressable for
[`ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html).

``` r

fit <- run(md_mi)            # m named MediationData
res <- pool(fit)             # pooled named MediationData + within/between/total vcov
res@tidy_table               # term, estimate, std_error, var_w, var_b, var_tot
```

------------------------------------------------------------------------

## 4. MBCO under MI: D4-stacking (and why it is hosted here)

### 4.1 Why MBCO does not commute with Rubin’s rules

MBCO tests $`H_0: a b = 0`$. Since $`a b = 0 \iff a = 0 \lor b = 0`$,
the constrained log-likelihood is the **branch union**:

``` math
T = 2\big[\ell_{\text{full}} - \max(\ell_{a=0},\ \ell_{b=0})\big].
```

That [`max()`](https://rdrr.io/r/base/Extremes.html) is non-linear, so
the MBCO statistic of the *pooled* estimate is **not** the pool of
per-imputation MBCO statistics. You cannot pool first and test second —
you need the per-imputation fits.

### 4.2 D4 combination

Hence `MDMediationFit` retains the per-imputation list (exposed by
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)),
and `infer(type = "mbco")` combines the per-imputation LRT statistics
with the **D4** rule (Chan & Meng 2022; Grund et al. 2021):

``` math
d_S = \tfrac{\text{LRT(stacked data)}}{K},\quad
r_4 = \max\!\Big(0, \tfrac{K+1}{k(K-1)}(\bar d - d_S)\Big),\quad
D_4 = \tfrac{d_S}{k(1+r_4)} \sim F_{k,\nu}.
```

### 4.3 Hosting decision

[`RMediation::mbco()`](https://data-wise.github.io/rmediation/reference/mbco.html)
is OpenMx-only with no MI entry point, so the D4 machinery is **hosted
in missingmed** (`R/mbco_mi.R`), ported from the Missing-Effect research
prototype. It reproduces the prototype **exactly** (max abs diff
$`\approx 5\times10^{-11}`$ across design cells). When `RMediation`
gains an MI entry point, this code should move upstream (`TODO` noted in
source).

------------------------------------------------------------------------

## 5. The IPW estimator

IPW is a robustness complement to MI (manuscript appendix): instead of
imputing, it **reweights the observed complete cases** to represent the
full sample under MAR. The whole estimator is a single internal branch,
`.ipw_run()`;
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) and
`infer(type = "mc")` are unchanged.

### 5.1 Pipeline

``` r

md <- set_md_mediation(df, Y ~ X + M + C, M ~ X + C, treatment = "X",
  mediator = "M", method = "ipw",
  weight_formula = NULL, weight_stabilize = TRUE, weight_trim = 0.99,
  se_type = "sandwich")
res <- pool(run(md))         # MDMediationFit(m = 1) -> MDMediationResult (B = 0)
infer(res, type = "mc")
```

Because there is a single weighted fit, `MDMediationFit@m = 1` and
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
reduces to $`\bar Q = Q_1,\ B = 0,\ T = \bar U`$ — the result is
structurally identical to an MI result, so nothing downstream changes.

### 5.2 Weight estimation

Let $`R = 1`$ mark a complete case over the model variables.

- **Joint complete-case model (default).** `weight_formula = NULL` fits
  $`\text{logit }P(R=1\mid Z)`$ on the **fully observed** model
  variables (the MAR drivers); a single `formula` overrides the
  predictors.
- **Per-variable / sequential factorization.** A *named list* of
  formulas fits one model per incomplete variable and multiplies:
  $`P(\text{complete}) = \prod_V P(R_V = 1\mid \cdot)`$, following the
  causal order $`X \to M \to Y`$.

**Stabilized weights** (`weight_stabilize = TRUE`, default) use a
treatment-only numerator to reduce variance:
``` math
w_i = \frac{\hat P(R=1\mid X_i)}{\hat P(R=1\mid Z_i)} .
```
**Trimming** (`weight_trim`) caps weights at an upper quantile of the
untrimmed complete-case weights; `1` disables it.

### 5.3 Variance: sandwich vs model

IPW’s weighted-GLM model-based vcov is optimistic (it ignores that
weights were estimated). `se_type = "sandwich"` (the IPW default) uses
heteroskedasticity-consistent `sandwich::vcovHC` instead. This is
implemented **in medfit** via an injectable `vcov_fun` threaded through
`extract_mediation()` (so the named-vcov assembly stays in one place);
missingmed just passes `se_type` through.

> MBCO for IPW is **not** implemented (a weighted LRT is
> methodologically distinct); `infer(type = "mbco")` on an IPW fit
> errors with guidance.

------------------------------------------------------------------------

## 5A. Non-gaussian models (`family_y`, `family_m`) and the scale of `a*b`

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
takes `engine`, `family_y` and `family_m` and forwards them to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
whose default engine already **is** `"glm"`. Both estimators and both
inference types therefore accept non-gaussian families with no extra
machinery: a binary mediator (`family_m = binomial()`), a binary outcome
(`family_y = binomial()`) and a count outcome (`family_y = poisson()`)
all run through `set_md_mediation() -> run() -> pool() -> infer()`.

### 5A.1 The scale caveat

For a non-identity link, `a` and `b` are **link-scale** coefficients, so
their product – and the Monte-Carlo interval around it – is on the link
scale too:

| Model | `a` | `b` | `a*b` is… |
|----|----|----|----|
| gaussian / gaussian | mean difference | mean difference | a mean difference |
| binomial mediator | log-odds | mean difference | change in Y per log-odds of M |
| binomial outcome | mean difference | log-odds | log-odds units |
| poisson outcome | mean difference | log-rate | log-rate units |

Two consequences worth stating plainly:

1.  `a*b` under a non-identity link is **not** a risk difference, a risk
    ratio or an odds ratio, and `exp(a*b)` does not produce one.
    Reporting it as such is a category error, not a rounding issue.
2.  Rubin’s rules are applied to the **coefficients**, which is
    standard. Pooling a transformed quantity (an odds ratio, say) is a
    different and much less well-behaved operation;
    [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
    deliberately does not do it.

Where a response-scale contrast is wanted – a natural direct/indirect
effect on the risk difference or risk-ratio scale – the mediation
formula must be applied to the fitted models, which is outside
missingmed’s orchestration remit. That is a fitting-layer concern
(medfit), not a pooling one.

### 5A.2 IPW plus a binomial family: the non-integer-successes warning

[`stats::glm()`](https://rdrr.io/r/stats/glm.html) emits
`non-integer #successes in a binomial glm!` whenever a binomial fit
receives non-integer prior weights. IPW weights are inverse sampling
probabilities, not trial counts, so the warning fires on every
`method = "ipw"` fit with a binomial family. It is a false alarm: the
weighted score equations being solved are exactly the ones IPW
specifies, and the point estimates and sandwich SEs are unaffected. It
is left unsuppressed rather than silenced, so that a genuine
non-integer-response mistake still surfaces.

------------------------------------------------------------------------

## 5B. MNAR sensitivity (`sensitivity_mnar()`)

The pipeline estimates under **MAR** — `mice` imputes under MAR by
construction. MAR versus MNAR is not testable from the observed data, so
there is nothing to estimate without an assumption imported from outside
it.
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
therefore produces a **curve**, not an estimate:

> if the unobserved values of the target sit `delta` units away from
> what MAR imputation implies, the indirect effect is *X*.

No rung is “the MNAR estimate”. Each is conditional on its own delta.

### 5B.1 Method

Delta-adjusted imputation in the pattern-mixture sense (van Buuren,
*FIMD* §9.2; Leacy et al. 2017). Per rung: re-impute with the shift
applied, then run the existing pipeline unchanged.

For a **continuous** target the canonical procedure imputes under MAR
and then adds the constant to the imputed values (Hayati Rezvan et
al. 2018) — which is what `mice`’s `post` argument does, and what this
implements. For a **categorical** target the shift instead belongs on
the imputation model’s linear predictor, with delta on the odds-ratio
scale; that is not implemented, and such targets error rather than
receiving a meaningless additive shift.

Re-imputation rebuilds from the `mids` object’s **stored settings**,
never from its recorded `call` — a `mids` built inside a function stores
a call referencing that function’s local variables, which does not
resolve anywhere else.

``` r

sens <- sensitivity_mnar(md, delta = c(0, -0.5, -1, -1.5, -2))
tidy(sens)
summary(sens)   # adds the tipping point, if the grid contains one
```

### 5B.2 What `delta` actually is — read before choosing a value

`delta` is a **conditional** sensitivity parameter (CSP): a difference
conditional on all remaining variables *and their missingness
indicators*. The quantity an analyst can actually reason about —
“non-respondents average half a point lower” — is a **marginal** one
(MSP). They are different numbers.

Supplying an elicited MSP where a CSP is expected is the standard
failure mode of this method. Tompsett et al. (2018) measure it: coverage
fell from 95% to **49.3%** when an elicited MSP was inserted directly as
the CSP.

`missingmed` cannot make the specified parameter marginal, but it can
show you the realized one. Every rung reports `msp`:

| delta (CSP) | msp (realized) | estimate |
|-------------|----------------|----------|
| 0           | 0.244          | 0.323    |
| −0.5        | −0.256         | 0.278    |
| −2          | −1.76          | 0.098    |

Two things to read off that table. First, `msp` is **non-zero at delta =
0** — under MAR, imputed values legitimately differ from observed ones
when missingness depends on covariates. Second, `msp` is not simply
`delta` shifted: the gap is a chained-equations effect. With a single
incomplete variable the increments coincide exactly; with more, part of
the shift circulates back through the other imputation models.

### 5B.3 Reading a tipping point

[`summary()`](https://rdrr.io/r/base/summary.html) reports the delta at
which the interval first includes zero. Judge plausibility on the
**realized `msp`**, not on the CSP: Tompsett et al. note a CSP-scale
tipping point has no direct clinical interpretation. Resseguier et al.
add the constraint that a tipping value must “correspond to reasonable
hypotheses supported by epidemiologic evidences” — a tipping point that
requires an implausible departure from MAR is *reassurance*, not a
warning.

### 5B.4 Limitations

| Limitation | Status |
|----|----|
| `method = "ipw"` | Errors. IPW has no imputations to shift; a weighting analogue is a different method with a different parameter. |
| Categorical targets | Errors. Needs a linear-predictor offset (§5B.1); v2. |
| `pmm` targets | Allowed, with a message: shifted values may leave the observed range `pmm` otherwise guarantees. |
| Imputation-model compatibility | **Assumed, not checked.** The `mids` arrives pre-built; if its imputation model is incompatible with the mediation model, the curve confounds departure-from-MAR with misspecification. `smcfcs` is the upstream fix. |
| CSP calibration | Not implemented. Searching for the CSP that realizes a target MSP (Tompsett et al. §8) is the principled fix for §5B.2; v2. |

------------------------------------------------------------------------

## 6. Cross-package engineering decisions

These changes were made upstream to satisfy missingmed’s contracts; each
is the “small upstream fix” that a new capability turned out to need.

| Decision | Where | Why |
|----|----|----|
| `fit_mediation(weights=)` via `do.call` (value inlined), added only when non-NULL | medfit | `glm` evaluates `weights` by NSE in the **formula’s** environment; passing it through `...` resolves to [`stats::weights`](https://rdrr.io/r/stats/weights.html) (a function). `do.call` inlines the vector; gating on non-NULL keeps the unweighted path byte-identical. |
| `se_type` -\> injectable `vcov_fun` in `extract_mediation` | medfit | Keeps named-vcov assembly in one place; `sandwich::vcovHC` swaps in for [`stats::vcov`](https://rdrr.io/r/stats/vcov.html) without missingmed re-implementing medfit’s alias expansion. |
| Tidiers exported with `@exportS3Method broom::tidy` | missingmed | Plain `@export` registers `S3method(tidy, *)` against the wrong generic; the package-qualified form binds to broom’s generic so [`tidy()`](https://generics.r-lib.org/reference/tidy.html)/[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) dispatch. |
| [`S7::S4_register()`](https://rconsortium.github.io/S7/reference/S4_register.html) per S7 class | missingmed | The legacy S4 generics (`print`/`summary`) require S7 classes to be S4-registered before S7 methods can attach. |
| `namespace` roclet enabled | missingmed | Lets roxygen regenerate NAMESPACE for the many new S7 exports (surfaced + fixed a latent `generics`/`broom` `tidy` import clash). |
| Pooled `MediationData` via copy-modify | missingmed | Inherits all medfit metadata; only estimates/vcov/paths change, so names stay intact for RMediation. |

------------------------------------------------------------------------

## 7. Design-choice summary

- **S7-first**, three classes mirroring the S4 ancestors; estimator and
  model as orthogonal axes.
- **Delegate fitting to medfit** (`fit_mediation`) rather than
  re-implement GLM mediation — keeps missingmed thin and the
  `MediationData` naming canonical.
- **Names are the API**: pooled estimates/vcov stay named so RMediation
  resolves paths by label.
- **MBCO hosted locally** until RMediation offers an MI entry point;
  exact parity with the research prototype is the acceptance bar.
- **IPW = thin
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  branch + passthrough
  [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)**;
  weights support both joint and sequential models, stabilized and
  trimmed; sandwich SE by default.
- **S4 deprecated** with
  [`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) shims for
  one cycle.

------------------------------------------------------------------------

## 8. References

- Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in Surveys*.
  Wiley.
- Chan, K. W., & Meng, X.-L. (2022). Multiple improvements of multiple
  imputation likelihood ratio tests. *Statistica Sinica*.
- Grund, S., Lüdtke, O., & Robitzsch, A. (2021). Pooling methods for
  likelihood-ratio tests with multiply imputed data. *Psychological
  Methods*.
- Seaman, S. R., & White, I. R. (2013). Review of inverse probability
  weighting for dealing with missing data. *Statistical Methods in
  Medical Research*.
- van Buuren, S. *Flexible Imputation of Missing Data*, 2nd ed., §9.2
  (delta adjustment).
- Leacy, F. P., Floyd, S., Yates, T. A., & White, I. R. (2017). Analyses
  of sensitivity to the missing-at-random assumption using multiple
  imputation with delta adjustment. *American Journal of Epidemiology*,
  185(4), 304-315.
- Tompsett, D. M., Leacy, F., Moreno-Betancur, M., Heron, J., &
  White, I. R. (2018). On the use of the not-at-random fully conditional
  specification (NARFCS) procedure in practice. *Statistics in
  Medicine*, 37(15), 2338-2353.
- Hayati Rezvan, P., Lee, K. J., & Simpson, J. A. (2018). Sensitivity
  analysis within the multiple imputation framework using
  delta-adjustment. *Longitudinal and Life Course Studies*, 9(3),
  259-278.
- Resseguier, N., Giorgi, R., & Paoletti, X. (2011). Sensitivity
  analysis when data are missing not-at-random. *Epidemiology*, 22(2),
  282-287.
